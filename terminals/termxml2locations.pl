#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Simple ();

my $usage = "Usage: $0 [ignored-polys.txt] < map.xml > terminfo.txt\n";
my $OVERRIDES = $ARGV[0];
die $usage if $OVERRIDES && !-f $OVERRIDES;

# setup
my $xml = XML::Simple::XMLin('-', 'KeyAttr' => [], 'ForceArray' => 1);
die $usage unless $xml;
my $entries = $xml->{'entry'};
die $usage unless $entries;

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
our @PANELS = qw(computer_terminal pattern_buffer
                 shield_refuel double_shield_refuel triple_shield_refuel
                 oxygen_refuel);

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
  
  if (1)
  {
    my (@terminfo);
    for my $side (@$sides)
    {
      if ($side->{'flags'} & 0x2)
      {
        my $poly = $polys->[$side->{'poly'}];
        next if HiddenPoly($poly);
        my $type = $PANEL_TYPES[$side->{'panel_type'}];
        next unless $type eq 'computer_terminal';
        push(@terminfo, [ $lines->[$side->{'line'}], $side->{'panel_permutation'} ]);
      }
    }
    for my $term (@terminfo)
    {
      my ($line, $perm) = @$term;
      my ($x1, $y1) = Coords($line->{'endpoint1'});
      my ($x2, $y2) = Coords($line->{'endpoint2'});
      my ($cx, $cy) = (($x1 + $x2)/2, ($y1 + $y2)/2);
      
      print sprintf("%d %d %d %d\n", $levelnum, $cx, $cy, $perm);
    }    
  }
}

exit;

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

sub FindPoly
{
  my ($index) = @_;
  return undef if $index < 0;
  return $polys->[$index];
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
