#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/mml.subs";

SetReadOffset(13366);
warn "Starting at: " . CurOffset() . "\n";

my @damages;
for my $damagenum (0..19)
{
  my $index = $damagenum;
  $index++ if $damagenum >= 3;  # M1 doesn't have damage_shotgun_projectile
  
  ReadSint16();  # damage type unused in MML
  
  push(@damages, {
        'index' => $index,
        'threshold' => ReadSint16(),
        'fade' => ReadSint16(),
        'sound' => ReadSint16(),
        });
} 
warn "Ending at: " . CurOffset() . "\n";
print FormatMML({ 'player' => { 'damage' => \@damages } });
