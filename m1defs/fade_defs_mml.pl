#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/mml.subs";

SetReadOffset(3218);
warn "Starting at: " . CurOffset() . "\n";

my @fades;
for my $fadenum (0..26)
{
  push(@fades, {
        'index' => $fadenum,
        'type' => ReadFadeTable(),
        'color' => ReadColor16(),
        'initial_opacity' => ReadFixedOne(),
        'final_opacity' => ReadFixedOne(),
        'period' => sprintf("%d", ReadMTicks() * 1000 / 60),
        'flags' => ReadUint8(),
        'priority' => 0,
        });
  ReadUint8();
} 
warn "Ending at: " . CurOffset() . "\n";
print FormatMML({ 'faders' => { 'fader' => \@fades } });

sub ReadFadeTable
{
  my %lookup = (
    906 => 0,
    914 => 1,
    922 => 2,
    930 => 3,
    938 => 4,
    );
  
  return $lookup{ ReadUint32() };
}
