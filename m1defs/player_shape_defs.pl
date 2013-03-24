#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";

SetReadOffset(13536);
warn "Starting at: " . CurOffset() . "\n";
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * weapon lists missing shotgun, SMG, double shotgun, ball
 * weapon lists contain zeroes at last position
 * data changes too numerous to list
 *
 *****/

const struct player_shape_definitions m1_player_shapes=
{
END

print ItemCommentLine(
  ReadSNone(),
  'collection');
print "\n";

print ItemCommentLine(
  ReadSNone(), ReadSNone(),
  'dying hard, dying soft');
print ItemCommentLine(
  ReadSNone(), ReadSNone(),
  'dead hard, dead soft');

print ItemCommentLine(
  '{' . ReadSNone(), ReadSNone(), ReadSNone(), ReadSNone(), ReadSNone() . '}',
  'legs: stationary, walking, running, sliding, airborne');

print ItemCommentLine(
  '{' . ReadSNone(), ReadSNone(), ReadSNone(), ReadSNone(),
  ReadSNone(), ReadSNone(), ReadSNone(), '0', ReadSNone(),
  '0', '0', '0}',
  'idle torsos: fists, magnum, fusion, assault, rocket, flamethrower, alien, shotgun, double pistol, double shotgun, da ball');
ReadSNone();

print ItemCommentLine(
  '{' . ReadSNone(), ReadSNone(), ReadSNone(), ReadSNone(),
  ReadSNone(), ReadSNone(), ReadSNone(), '0', ReadSNone(),
  '0', '0', '0}',
  'charging torsos: fists, magnum, fusion, assault, rocket, flamethrower, alien, shotgun, double pistol, double shotgun, ball');
ReadSNone();

print ItemCommentLine(
  '{' . ReadSNone(), ReadSNone(), ReadSNone(), ReadSNone(),
  ReadSNone(), ReadSNone(), ReadSNone(), '0', ReadSNone(),
  '0', '0', '0}',
  'firing torsos: fists, magnum, fusion, assault, rocket, flamethrower, alien, shotgun, double pistol, double shotgun, ball');
ReadSNone();

print <<END;
};
END
warn "Ending at: " . CurOffset() . "\n";
