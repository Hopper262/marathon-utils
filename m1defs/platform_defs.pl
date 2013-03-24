#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";

SetReadOffset(5012);
warn "Starting at: " . CurOffset() . "\n";
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * moving_sound, key_item_index not present
 * _platform_is_door flag not present
 * 6 entries total
 * data changes too numerous to list (see comments for similarities)
 *
 *****/

struct platform_definition m1_platform_definitions[]=
{
END

my @PFLAGS = map { ' FLAG(' . $_ . ') ' } split("\n", <<END);
_platform_is_initially_active
_platform_is_initially_extended
_platform_deactivates_at_each_level
_platform_deactivates_at_initial_level
_platform_activates_adjacent_platforms_when_deactivating
_platform_extends_floor_to_ceiling
_platform_comes_from_floor
_platform_comes_from_ceiling
_platform_causes_damage
_platform_does_not_activate_parent
_platform_activates_only_once
_platform_activates_light
_platform_deactivates_light
_platform_is_player_controllable
_platform_is_monster_controllable
_platform_reverses_direction_when_obstructed
_platform_cannot_be_externally_deactivated
_platform_uses_native_polygon_heights
_platform_delays_before_activation
_platform_activates_adjacent_platforms_when_activating
_platform_deactivates_adjacent_platforms_when_activating
_platform_deactivates_adjacent_platforms_when_deactivating
_platform_contracts_slower
_platform_activates_adjacent_platforms_at_each_level
_platform_is_locked
_platform_is_secret
_platform_is_door
END


my @PNAMES = split("\n", <<END);
Marathon door - similar to spht_door
similar to spht_platform
similar to noisy_spht_platform
Pfhor door - mix of heavy_spht_door and pfhor_door
silent version of heavy_spht_platform
similar to heavy_spht_platform
END

for my $platnum (0..5)
{
  print "	{ // $PNAMES[$platnum]\n";
  print ItemLine(ReadSoundId(), ReadSoundId());
  print ItemLine(ReadSoundId(), ReadSoundId());
  print ItemLine(ReadSoundId(), ReadSoundId());
  print ItemLine('NONE');
  
  print "\n";
  print ItemCommentLine('NONE', 'key item index');
  print "\n";
  
  print "		{ /* defaults */\n";
  print '			' . join(', ',
    ReadPlatType(),
    ReadPlatSpeed(), ReadPlatDelay(),
    ReadWorldOne(), ReadWorldOne(),
    ReadPlatFlags());
  
  if ($platnum == 0 || $platnum == 3)
  {
    # deal with hardcoded door slots
    print '| FLAG(_platform_is_door)';
  }
  print "\n";
  
  ReadPadding(18);  
  print "		},\n\n";
  
  print '		' . ReadDamage() . " /* damage, if necessary */\n";
  
  print "	},\n";
}
print <<END;
};
END
warn "Ending at: " . CurOffset() . "\n";


sub ReadPlatType
{
  ## M1 and M2 names are different
  return ReadSint16();
}

sub ReadPlatFlags
{
  return ReadFlags32(\@PFLAGS);
}

sub ReadPlatSpeed
{
  return ReadEnum16({
        int(1024/120) => '_very_slow_platform',
        int(1024/60)  => '_slow_platform',
      2*int(1024/60)  => '_fast_platform',
      3*int(1024/60)  => '_very_fast_platform',
      4*int(1024/60)  => '_blindingly_fast_platform',
    });
}

sub ReadPlatDelay
{
  return ReadEnum16({
           0 => '_no_delay_platform',
          30 => '_short_delay_platform',
        2*30 => '_long_delay_platform',
        4*30 => '_very_long_delay_platform',
        8*30 => '_extremely_long_delay_platform',
    });
}
