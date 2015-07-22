#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Simple ();

my $usage = "Usage: $0 < map.xml > ignore-candidates.txt\n";
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

our ($points, $lines, $sides, $polys, $platforms, $notes, $liquids, $objects);
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
  $objects = FindChunk($level, 'OBJS') || [];
  FixSides();
  
  my (@groups, %seen_polys);
  for my $poly_idx (0..(scalar(@$polys)-1))
  {
    next if $seen_polys{$poly_idx};
    
    my %cur_polys;
    my @queue = ($poly_idx);
    while (scalar @queue)
    {
      my $idx = shift @queue;
      next if $seen_polys{$idx};
      $seen_polys{$idx} = 1;
      $cur_polys{$idx} = 1;
      
      my $poly = $polys->[$idx];
      for my $v (0..($poly->{'vertex_count'} - 1))
      {
        # adjacent polygons may not be set right; lines seem OK
        my $line = $lines->[$poly->{'line_index_' . $v}];
        for my $dir ('cw', 'ccw')
        {
          my $across = $line->{$dir . '_poly'};
          next if $across < 0 || $across == $idx || $seen_polys{$across};
          push(@queue, $across);
        }
      }
    }
    push(@groups, \%cur_polys) if scalar keys %cur_polys;
  }
  
  # no ignores if everything is connected
  next unless scalar(@groups) > 1;
  
  my %good_polys;
  my $remsub = sub {
      my ($idx) = @_;
      my @removed;
      for my $gidx (0..(scalar(@groups) - 1))
      {
        if ($groups[$gidx]{$idx})
        {
          push(@removed, keys(%{ splice(@groups, $gidx, 1) }));
          last;
        }
      }
      map { $good_polys{$_} = 1 } @removed;
      return @removed;
    };
  
  # filter groups containing player starts
  for my $obj (@$objects)
  {
    next unless $obj->{'type'} == 3;
    $remsub->($obj->{'polygon_index'});
  }  

  # identify teleport destinations
  my (%telescripts, %telepolys);
  for my $term (@{ FindChunk($level, 'term') || [] })
  {
    for my $group (@{ $term->{'grouping'} || [] })
    {
      next unless $group->{'type'} == 7;
      my $dest = $group->{'permutation'};
      next if $good_polys{$dest};
      my $tnum = $term->{'index'};
      $telescripts{$tnum}{$dest} = 1;
    }
  }
  
  if (scalar keys %telescripts)
  {
    for my $side (@$sides)
    {
      if ($side->{'flags'} & 0x2)
      {
        my $type = $PANEL_TYPES[$side->{'panel_type'}];
        next unless $type eq 'computer_terminal';
        my $tnum = $side->{'panel_permutation'};
        next unless $telescripts{$tnum};
        for my $dest (keys %{ $telescripts{$tnum} })
        {
          $telepolys{$side->{'poly'}}{$dest} = 1;
        }
      }
    }
  }
  
  for my $poly (@$polys)
  {
    next unless $poly->{'type'} == 10;
#     warn "Found intralevel teleport from $poly->{'index'} to $poly->{'permutation'}\n";
    $telepolys{$poly->{'index'}}{$poly->{'permutation'}} = 1;
  }
  
  if (scalar keys %telepolys)
  {
    # Keep trying to reach teleporters, until we:
    #  1. reach everything in the level
    #  2. stop reaching new areas
    # We can't tell if the teleporters can actually
    # be reached, but erring on the side of reachability
    # is okay for this purpose.
    my $any_matched = 1;
    while (scalar(@groups) && $any_matched)
    {
      $any_matched = 0;
      for my $idx (keys %telepolys)
      {
        next unless $good_polys{$idx};
        my $ref = $telepolys{$idx};
        for my $dest (keys %$ref)
        {
          next if $good_polys{$dest};
          $remsub->($dest);
          $any_matched = 1;
        }
      }
    }
  }
  
  # no ignores if everything is reachable now
  next unless scalar(@groups) > 0;
  
  # export
  my %ignores = map { %$_ } @groups;
  my @list;
  my ($first, $latest);
  for my $key (sort { ($a + 0) <=> ($b + 0) } keys(%ignores))
  {
    unless (defined $first)
    {
      $first = $latest = $key;
      next;
    }
    if ($key == ($latest + 1))
    {
      $latest = $key;
    }
    elsif ($first < $latest)
    {
      push(@list, "$first-$latest");
      $first = $latest = $key;
    }
    else
    {
      push(@list, $first);
      $first = $latest = $key;
    }
  }
  
  if (defined $first)
  {
    if ($first < $latest)
    {
      push(@list, "$first-$latest");
    }
    else
    {
      push(@list, $first);
    }
  }
  print sprintf("%3d: %-20s # %s\n", $levelnum, join(' ', @list), $levelname);
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
  return 0;
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
