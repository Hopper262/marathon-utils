#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Simple ();

my ($scenario, $OVERRIDES) = @ARGV;
die "Usage: $0 <scenario> [<ignored-polys.txt>] < map.xml > info.txt\n" unless $scenario;

my @ignore_list;
if (defined $OVERRIDES)
{
  my $overfh;
  open($overfh, '<', $OVERRIDES) or die;
  while (my $line = <$overfh>)
  {
    chomp $line;
    next unless $line =~ s/^(\d+):\s+//;
    my $levnum = $1;
    
    my %hashed;
    for my $poly (split(/\s+/, $line))
    {
      if ($poly =~ /^(\d+)-(\d+)$/)
      {
        for my $index ($1..$2)
        {
          $hashed{$index} = 1;
        }
      }
      elsif ($poly =~ /^(\d+)$/)
      {
        $hashed{$1} = 1;
      }
    }
    $ignore_list[$levnum] = { %hashed };
  }
}

my $xml = XML::Simple::XMLin('-', 'KeyAttr' => [], 'ForceArray' => 1);
die unless $xml;
my $entries = $xml->{'entry'};
die unless $entries;

our $M1_MODE = ($xml->{'wadinfo'}[0]{'type'} < 2);
our @PANEL_TYPES;
if ($M1_MODE)
{
  @PANEL_TYPES = qw(
      oxygen_refuel shield_refuel double_shield_refuel
      triple_shield_refuel light_switch platform_switch
      pattern_buffer tag_switch computer_terminal tag_switch
      double_shield_refuel triple_shield_refuel platform_switch
      pattern_buffer
    );
}
else
{
  @PANEL_TYPES = qw(
      oxygen_refuel shield_refuel double_shield_refuel tag_switch
      light_switch platform_switch tag_switch pattern_buffer
      computer_terminal tag_switch

      shield_refuel double_shield_refuel triple_shield_refuel
      light_switch platform_switch tag_switch pattern_buffer
      computer_terminal oxygen_refuel tag_switch tag_switch

      shield_refuel double_shield_refuel triple_shield_refuel
      light_switch platform_switch tag_switch pattern_buffer
      computer_terminal oxygen_refuel tag_switch tag_switch

      shield_refuel double_shield_refuel triple_shield_refuel
      light_switch platform_switch tag_switch pattern_buffer
      computer_terminal oxygen_refuel tag_switch tag_switch

      shield_refuel double_shield_refuel triple_shield_refuel
      light_switch platform_switch tag_switch pattern_buffer
      computer_terminal oxygen_refuel tag_switch tag_switch
    );
}

our ($points, $lines, $sides, $polys, $platforms, $notes, $liquids, $ignores);
for my $levelnum (0..(scalar(@$entries)-1))
{
  my $level = $entries->[$levelnum];
  my $infochunk = FindChunk($level, 'Minf');
  next unless $infochunk && $infochunk->[0];
  my $levelname = $infochunk->[0]{'content'} || '(unnamed)';
  warn "Processing $levelnum. $levelname\n";

  $points = FindChunk($level, 'EPNT') || FindChunk($level, 'PNTS');
  $lines = FindChunk($level, 'LINS');
  $sides = FindChunk($level, 'SIDS');
  $polys = FindChunk($level, 'POLY');
  $platforms = FindChunk($level, 'plat') || FindChunk($level, 'PLAT');
  $notes = FindChunk($level, 'NOTE') || [];
  $liquids = FindChunk($level, 'medi') || [];
  $ignores = $ignore_list[$levelnum] || {};
  
  FixSides();
  
  my $output = sub {
      my ($type, @values) = @_;
      my @nvals = grep { defined } @values;
      next unless scalar @nvals;
      print "$scenario $levelnum $type " . join(':!:', @nvals) . "\n";
    };
  
  $output->('polygons', scalar @$polys);
  my $area = 0;
  for my $poly (@$polys)
  {
    next if HiddenPoly($poly);
    $area += PolyArea($poly);
  }
  $output->('area', sprintf('%d', $area));
  
  my $notes = FindChunk($level, 'NOTE');
  if ($notes)
  {
    $output->('annotations', map { $_->{'content'} } @$notes);
  }
  
  my (%panel_polys);
  for my $side (@$sides)
  {
    if ($side->{'flags'} & 0x2)
    {
      my $poly = $polys->[$side->{'poly'}];
      next if HiddenPoly($poly);
      my $type = $PANEL_TYPES[$side->{'panel_type'}];
      $panel_polys{$type}{$side->{'poly'}} = 1;
    }
  }
  for my $ptype (qw(shield_refuel double_shield_refuel triple_shield_refuel
                    pattern_buffer computer_terminal oxygen_refuel))
  {
    my $ct = scalar keys %{ $panel_polys{$ptype} };
    $output->($ptype, $ct) if $ct;
  }
}
exit;

sub FixSides
{
  for my $line (@$lines)
  {
    for my $dir ('cw', 'ccw')
    {
      my $poly_index = $line->{$dir . '_poly'};
      my $side_index = $line->{$dir . '_side'};
      if ($poly_index >= 0 && $side_index >= 0)
      {
        my $side = $sides->[$side_index];
        $side->{'line'} = $line->{'index'};
        $side->{'poly'} = $poly_index;
      }
    }
  }
}

sub FindChunk
{
  my ($level, $chunkname) = @_;
  
  for my $chunk (@{ $level->{'chunk'} })
  {
    if ($chunk->{'type'} eq $chunkname)
    {
      for my $key (keys %$chunk)
      {
        next if $key eq 'type';
        next if $key eq 'size';
        return $chunk->{$key};
      }
    }
  }
  return undef;
}

sub LandscapedPoly
{
  my ($poly) = @_;
  return $poly->{'floor_transfer_mode'} == 9 &&
         $poly->{'ceiling_transfer_mode'} == 9;
}
sub UnseenPoly
{
  my ($poly) = @_;
  return $poly->{'type'} != 5 &&
         $poly->{'floor_height'} == $poly->{'ceiling_height'};
}
sub IgnoredPoly
{
  my ($poly) = @_;
  return $ignores->{$poly->{'index'}};
}
sub HiddenPoly
{
  my ($poly) = @_;
  return LandscapedPoly($poly) || UnseenPoly($poly) || IgnoredPoly($poly);
}

sub Coords
{
  my ($index) = @_;
  my $pt = $points->[$index];
  return ($pt->{'x'}, $pt->{'y'});
}

sub SolidLine
{
  my ($line) = @_;
  return $line->{'flags'} & 0x4000 ||
         $line->{'cw_poly'} < 0 ||  # work around bad maps
         $line->{'ccw_poly'} < 0 ||
         $polys->[$line->{'cw_poly'}]->{'type'} == 5 ||
         $polys->[$line->{'ccw_poly'}]->{'type'} == 5;
}

sub LandscapedLine
{
  my ($line) = @_;
  return (($line->{'cw_side'} >= 0 &&
           $sides->[$line->{'cw_side'}]->{'primary_transfer'} == 9) ||
          ($line->{'ccw_side'} >= 0 &&
           $sides->[$line->{'ccw_side'}]->{'primary_transfer'} == 9));
}

sub SecretPoly
{
  my ($poly) = @_;
  
  return 0 unless $poly->{'type'} == 5;
  my $plat;
  if ($M1_MODE)
  {
    for my $p (@$platforms)
    {
      if ($p->{'polygon_index'} == $poly->{'index'})
      {
        $plat = $p;
        last;
      }
    }
  }
  else
  {
    $plat = $platforms->[$poly->{'permutation'}];
  }
  return 0 unless $plat;
  return $plat->{'static_flags'} & 0x2000000;
}

sub PolyArea
{
  my ($poly) = @_;
  
  my $area = 0;
  my $vcount = $poly->{'vertex_count'};
  for my $v (0..($vcount - 1))
  {
    my ($cx, $cy) = Coords($poly->{'endpoint_index_' . $v});
    my ($nx, $ny) = Coords($poly->{'endpoint_index_' . (($v + 1) % $vcount)});
    $area += $cx * $ny;
    $area -= $nx * $cy;
  }
  $area /= 2*1024*1024;
  return $area < 0 ? -$area : $area;
}
