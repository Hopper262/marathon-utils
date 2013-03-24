#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/mml.subs";

SetReadOffset(16150);
warn "Starting at: " . CurOffset() . "\n";

my @scenery;
for my $scenum (0..16)
{
  push(@scenery, {
          'index' => $scenum,
          'flags' => ReadUint16(),
          'normal' => [ { 'shape' => ReadDescriptor() } ],
          'radius' => ReadWorldOne(),
          'height' => ReadWorldOne(),
          'destruction' => -1,
          });
}

warn "Ending at: " . CurOffset() . "\n";
print FormatMML({ 'scenery' => { 'object' => \@scenery } });
