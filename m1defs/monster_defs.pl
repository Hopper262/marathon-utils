#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";

SetReadOffset(7846);
warn "Starting at: " . CurOffset() . "\n";
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * sound_pitch, clear_sound through friendly_fire_sound not present
 * contrail_effect not present
 * teleport_in_shape, teleport_out_shape not present
 * data changes too numerous to list
 *
 *****/

const struct monster_definition m1_original_monster_definitions[]=
{
END

my @MON_FLAGS = split("\n", <<END);
_monster_is_omniscent
_monster_flys
_monster_is_alien
_monster_major
_monster_minor
_monster_cannot_be_dropped
_monster_floats
_monster_cannot_attack
_monster_uses_sniper_ledges
_monster_is_invisible
_monster_is_subtly_invisible
_monster_is_kamakazi
_monster_is_berserker
_monster_is_enlarged
_monster_has_delayed_hard_death
_monster_fires_symmetrically
_monster_has_nuclear_hard_death
_monster_cant_fire_backwards
_monster_can_die_in_flames
_monster_waits_with_clear_shot
_monster_is_tiny
_monster_attacks_immediately
_monster_is_not_afraid_of_water
_monster_is_not_afraid_of_sewage
_monster_is_not_afraid_of_lava
_monster_is_not_afraid_of_goo
_monster_can_teleport_under_media
_monster_chooses_weapons_randomly
END

for my $monnum (0..40)
{
  print "	{\n";
  
  my $coll = ReadSint16();
  if ($coll == 0)
  {
    print "		0\n	},\n\n";
    ReadPadding(136);
    next;
  }
  
  print ItemCommentLine(
    FormatCollection($coll % 32, int($coll / 32)), 'shape collection');
  print ItemCommentLine(
    ReadSint16(), ReadWeaknesses(), ReadWeaknesses(),
    'vitality, immunities, weaknesses');
  print ItemCommentLine(
    ReadMonFlags(), 'flags');
  
  print "\n";
  print ItemCommentLine(
    ReadMonClass(), 'class');
  print ItemCommentLine(
    ReadMonClass(), 'friends');
  print ItemCommentLine(
    ReadMonClass(), 'enemies');
  
  print "\n";
  print ItemCommentLine(
    '_normal_frequency', 'sound pitch');
  print ItemCommentLine(
    ReadSoundId(), ReadSoundId(), 'NONE', 'NONE', 'NONE', 'NONE',
    'sounds: activation, friendly activation, clear, kill, apology, friendly-fire');
  print ItemCommentLine(
    ReadSoundId(), 'flaming death sound');
  print ItemCommentLine(
    ReadSoundId(), ReadSint16(),
    'random sound, random sound mask');
  
  print "\n";
  print ItemCommentLine(
    ReadItemId(), 'carrying item type');
  
  print "\n";
  print ItemCommentLine(
    ReadWorldOne(), ReadWorldOne(), 'radius, height');
  print ItemCommentLine(
    ReadWorldOne(), 'preferred hover height');
  print ItemCommentLine(
    ReadWorldOne(), ReadWorldOne(),
    'minimum ledge delta, maximum ledge delta');
  print ItemCommentLine(
    ReadFixedOne(), 'external velocity scale');
  print ItemCommentLine(
    ReadEffectType(), ReadEffectType(), 'NONE',
    'impact effect, melee impact effect, contrail effect');
  
  print "\n";
  print ItemCommentLine(
    ReadAngle(), ReadAngle(),
    'half visual arc, half vertical visual arc');
  print ItemCommentLine(
    ReadWorldOne(), ReadWorldOne(),
    'visual range, dark visual range');
  print ItemCommentLine(
    ReadIntelligence(), 'intelligence');
  print ItemCommentLine(
    ReadMonSpeed(), 'speed');
  print ItemCommentLine(
    ReadGravity(), ReadTerminal(), 'gravity, terminal velocity');  
  print ItemCommentLine(
    ReadDoorRetry(), 'door retry mask');
  print ItemCommentLine(
    ReadWorldOne(), ReadDamage(),
    'shrapnel radius, shrapnel damage');
    
  print "\n";
  print ItemCommentLine(
    ReadUNone(), 'being hit');
  print ItemCommentLine(
    ReadUNone(), ReadUNone(), 'dying hard (popping), dying soft (falling)');
  print ItemCommentLine(
    ReadUNone(), ReadUNone(), 'hard dead frames, soft dead frames');
  print ItemCommentLine(
    ReadUNone(), ReadUNone(), 'stationary shape, moving shape');
  print ItemCommentLine(
    'UNONE', 'UNONE', 'teleport in shape, teleport out shape');
  
  print "\n";
  print ItemCommentLine(
    ReadTicks(), 'attack frequency');
  
  for my $attack ('melee', 'ranged')
  {
    print "\n";
    print "		/* $attack attack */\n";
    print "		{\n";
    
    my $type = ReadSNone();  # don't bother with symbols, projectiles differ
    print '	' . ItemCommentLine(
      $type, "$attack attack type");
    
    if ($type eq 'NONE')
    {
      ReadPadding(14);
    }
    else
    {
      print '	' . ItemCommentLine(
        ReadSint16(), 'repetitions');
      print '	' . ItemCommentLine(
        ReadAngle(), 'error angle');
      print '	' . ItemCommentLine(
        ReadWorldOne(), 'range');
      print '	' . ItemCommentLine(
        ReadSint16(), "$attack attack shape");

      print "\n";
      print '	' . ItemCommentLine(
        ReadWorldOne(), ReadWorldOne(), ReadWorldOne(),
        'dx, dy, dz');
    }
    print "		},\n";
  }
  
  print "	},\n	\n";
}
print <<END;
};
END
warn "Ending at: " . CurOffset() . "\n";


sub ReadMonFlags
{
  return ReadFlags32(\@MON_FLAGS);
}
sub ReadMonClass
{
  my $raw = ReadUint32();
  return '-1' if $raw == 4294967295;
  return '0' if $raw == 0;
  my $res = FormatFlags($raw, 
                [qw(_class_player
                    _class_human_civilian
                    _class_madd
                    _class_possessed_hummer
                    _class_defender
                    _class_fighter
                    _class_trooper
                    _class_hunter
                    _class_enforcer
                    _class_juggernaut
                    _class_hummer
                    _class_compiler
                    _class_cyborg
                    _class_assimilated_civilian
                    _class_tick
                    _class_yeti)]);
  $res =~ s/_class_player\|_class_human_civilian\|_class_madd\|_class_possessed_hummer/_class_human/;
  $res =~ s/_class_fighter\|_class_trooper\|_class_hunter\|_class_enforcer\|_class_juggernaut/_class_pfhor/;
  $res =~ s/_class_compiler\|_class_assimilated_civilian\|_class_cyborg\|_class_hummer/_class_client/;
  $res =~ s/_class_tick\|_class_yeti/_class_native/;
  $res =~ s/_class_pfhor\|_class_client/_class_hostile_alien/;
  
  return $res;
}

sub ReadIntelligence
{
  return ReadEnum16({
      2 => '_intelligence_low',
      3 => '_intelligence_average',
      8 => '_intelligence_high',
      65535 => 'NONE',
      });
}
sub ReadDoorRetry
{
  return ReadEnum16({
      63 => '_slow_door_retry_mask',
      31 => '_normal_door_retry_mask',
      15 => '_fast_door_retry_mask',
       3 => '_vidmaster_door_retry_mask',
      65535 => 'NONE',
       });
}
sub ReadMonSpeed
{
  return ReadEnum16({
    int(1024/120) => '_speed_slow',
    int(1024/80)  => '_speed_medium',
    int(1024/70)  => '_speed_almost_fast',
    int(1024/40)  => '_speed_fast',
    int(1024/30)  => '_speed_superfast1',
    int(1024/28)  => '_speed_superfast2',
    int(1024/26)  => '_speed_superfast3',
    int(1024/24)  => '_speed_superfast4',
    int(1024/22)  => '_speed_superfast5',
    int(1024/20)  => '_speed_blinding',
    int(1024/10)  => '_speed_insane',
    });
}
sub ReadGravity
{
  return ReadEnum16({
    int(1024/120) => 'NORMAL_MONSTER_GRAVITY',
    });
}
sub ReadTerminal
{
  return ReadEnum16({
    int(1024/14) => 'NORMAL_MONSTER_TERMINAL_VELOCITY',
    });
}
