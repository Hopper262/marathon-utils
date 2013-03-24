#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/mml.subs";

SetReadOffset(5012);
warn "Starting at: " . CurOffset() . "\n";

my @plats;
for my $platnum (0..5)
{
  my %hash = (
    'index' => $platnum,
    'start_extend' => ReadSoundId(),
    'start_contract' => ReadSoundId(),
    'stop_extend' => ReadSoundId(),
    'stop_contract' => ReadSoundId(),
    'obstructed' => ReadSoundId(),
    'uncontrollable' => ReadSoundId(),
    'moving' => -1,
    'item' => -1,
    );
  
  ReadPadding(32);  # skip defaults
  
  $hash{'damage'} = ReadDamage();
  push(@plats, \%hash);
}
warn "Ending at: " . CurOffset() . "\n";
print FormatMML({ 'platforms' => { 'platform' => \@plats } });

