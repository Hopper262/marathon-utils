#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/mml.subs";

SetReadOffset(14474);
warn "Starting at: " . CurOffset() . "\n";

my @items;
for my $itemnum (0..19)
{
  push(@items, {
    'index' => $itemnum,
    'type' => ReadUint16(),
    'singular' => ReadSint16(),
    'plural' => ReadSint16(),
    'shape' => ReadDescriptor(),
    'maximum' => ReadSint16(),
    'invalid' => ReadUint16(),
    });
}
warn "Ending at: " . CurOffset() . "\n";
print FormatMML({ 'items' => { 'item' => \@items } });
