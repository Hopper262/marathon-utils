#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";

SetReadOffset(15018);
warn "Starting at: " . CurOffset() . "\n";
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * media_detonation_effect, media_projectile_promotion not present
 * sound_pitch, rebound_sound not present
 * flags is 16-bit; flags past _melee_projectile not present
 * AR damage is 8/8 instead of 9/6
 * data changes too numerous to list
 *
 *****/

const struct projectile_definition m1_original_projectile_definitions[]=
{
END

my @PROJ_FLAGS = split("\n", <<END);
_guided
_stop_when_animation_loops
_persistent
_alien_projectile
_affected_by_gravity
_no_horizontal_error
_no_vertical_error
_can_toggle_control_panels
_positive_vertical_error
_melee_projectile
_persistent_and_virulent
_usually_pass_transparent_side
_sometimes_pass_transparent_side
_doubly_affected_by_gravity
_rebounds_from_floor
END

for my $projnum (0..24)
{
  print "	{\n";
  print ItemCommentLine(
    ReadCollectionSOpt(), ReadSint16(),
    'collection number, shape number');
  print ItemCommentLine(
    ReadEffectType(), 'NONE',
    'detonation effect, media_detonation_effect');
  print ItemCommentLine(
    ReadEffectType(), ReadSint16(), ReadSNone(),
    'contrail effect, ticks between contrails, maximum contrails');
  print ItemCommentLine(
    'NONE', 'media projectile promotion');
  
  print "\n";
  print ItemCommentLine(
    ReadWorldOne(), 'radius');
  print ItemCommentLine(
    ReadWorldOne(), 'area-of-effect');
    
  print ItemCommentLine(
    ReadDamage(), 'damage');
  
  print "		\n";
  print ItemCommentLine(
    ReadProjFlags(), 'flags');
  
  print "		\n";
  print ItemCommentLine(
    ReadProjSpeed(), 'speed');
  print ItemCommentLine(
    ReadProjDist(), 'maximum range');
    
  print "\n";
  print ItemCommentLine(
    '_normal_frequency', 'sound pitch');
  print ItemCommentLine(
    ReadSoundId(), 'NONE', 'flyby sound, rebound sound');
  
  print "	},\n	\n";
}
print <<END;
};
END
warn "Ending at: " . CurOffset() . "\n";


sub ReadProjFlags
{
  return ReadFlags16(\@PROJ_FLAGS);
}
sub ReadProjSpeed
{
  my $res = ReadUint16();
  return 'WORLD_ONE' if $res == 65535;
  return FormatWorldOne($res);
}
sub ReadProjDist
{
  my $res = ReadUint16();
  return 'NONE' if $res == 65535;
  return FormatWorldOne($res);
}
