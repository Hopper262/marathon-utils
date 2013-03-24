#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/mml.subs";

SetReadOffset(13536);
warn "Starting at: " . CurOffset() . "\n";

my @shapes;

# collection, dying hard, dying soft, dead hard, dead soft
push(@shapes, {
      'type' => 0, 'subtype' => 0, 'value' => ReadSint16() });
push(@shapes, {
      'type' => 0, 'subtype' => 1, 'value' => ReadSint16() });
push(@shapes, {
      'type' => 0, 'subtype' => 2, 'value' => ReadSint16() });
push(@shapes, {
      'type' => 0, 'subtype' => 3, 'value' => ReadSint16() });
push(@shapes, {
      'type' => 0, 'subtype' => 4, 'value' => ReadSint16() });

# legs
push(@shapes, {
      'type' => 1, 'subtype' => 0, 'value' => ReadSint16() });
push(@shapes, {
      'type' => 1, 'subtype' => 1, 'value' => ReadSint16() });
push(@shapes, {
      'type' => 1, 'subtype' => 2, 'value' => ReadSint16() });
push(@shapes, {
      'type' => 1, 'subtype' => 3, 'value' => ReadSint16() });
push(@shapes, {
      'type' => 1, 'subtype' => 4, 'value' => ReadSint16() });

# idle, charging, firing
for my $type (2..4)
{
  push(@shapes, {
        'type' => $type, 'subtype' => 0, 'value' => ReadSint16() });
  push(@shapes, {
        'type' => $type, 'subtype' => 1, 'value' => ReadSint16() });
  push(@shapes, {
        'type' => $type, 'subtype' => 2, 'value' => ReadSint16() });
  push(@shapes, {
        'type' => $type, 'subtype' => 3, 'value' => ReadSint16() });
  push(@shapes, {
        'type' => $type, 'subtype' => 4, 'value' => ReadSint16() });
  push(@shapes, {
        'type' => $type, 'subtype' => 5, 'value' => ReadSint16() });
  push(@shapes, {
        'type' => $type, 'subtype' => 6, 'value' => ReadSint16() });
  push(@shapes, {
        'type' => $type, 'subtype' => 10, 'value' => ReadSint16() });
  ReadSint16();  # zero - ignore
}

warn "Ending at: " . CurOffset() . "\n";
print FormatMML({ 'player' => {
                    'shape' => \@shapes } });
