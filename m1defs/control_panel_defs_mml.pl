#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/mml.subs";

SetReadOffset(7704);
warn "Starting at: " . CurOffset() . "\n";

my @panels;
for my $pnum (0..13)
{
  my $idx = ReadSint16();
  my %hash = (
    'index' => $idx,
    'type' => LookupType($idx),
    'item' => LookupItem($idx),
    );
  
  my $act_shape = ReadDescriptor();
  $hash{'coll'} = $act_shape->{'coll'};
  $hash{'active_frame'} = $act_shape->{'seq'};
  
  my $in_shape = ReadDescriptor();
  $hash{'inactive_frame'} = $in_shape->{'seq'};
  
  $hash{'sound'} = [
      { 'type' => 0, 'which' => ReadSoundId() },
      { 'type' => 1, 'which' => ReadSoundId() },
      { 'type' => 2, 'which' => '20180' },  # hardcoded in engine
    ];
  
  push(@panels, \%hash);
}
warn "Ending at: " . CurOffset() . "\n";
print FormatMML({ 'control_panels' => { 'panel' => \@panels } });

sub LookupType
{
  my ($idx) = @_;
  
  my @types = qw(0 1 2 3 4 5 7 6 8 6 2 3 5 7);
  return $types[$idx];
}
sub LookupItem
{
  my ($idx) = @_;
  
  return ($idx == 9) ? 18 : -1;
}
  
