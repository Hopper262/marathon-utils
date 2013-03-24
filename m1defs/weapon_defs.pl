#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";

SetReadOffset(13634);
warn "Starting at: " . CurOffset() . "\n";
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * structure refactored into trigger_definition for M2;
 *   layout taken from Bovine source code
 * no powerup_type
 * no loading_ticks, finish_loading_ticks, powerup_ticks
 * unused instant_reload_tick(?) field discarded
 * no trigger charged_sound, shell_casing_type
 * weapon flags are different
 * data changes too numerous to list
 *
 *****/

const struct weapon_definition m1_original_weapon_definitions[]=
{
END

my @CLASSES = split("\n", <<END);
_melee_class
_normal_class
_dual_function_class
_twofisted_pistol_class
_multipurpose_class
END
my @WEPNAMES = split("\n", <<END);
Fist
Magnum .45 "mega class"- dual fisted
Fusion Pistol
Assault Rifle
Rocket Launcher
flamethrower
alien weapon
END
for my $wepnum (0..6)
{
  my @triggers = ({}, {});
  
  print "	/* $WEPNAMES[$wepnum] */\n";
  print "	{\n";
  print "		/* item type, powerup type, item class, item flags */\n";
  print ItemLine(ReadItemId(), 'NONE', ReadWClass(), ReadWFlags());
  print "\n";
  
  $triggers[0]{'ammo_type'} = ReadItemId();
  $triggers[0]{'rounds_per'} = ReadSint16();
  $triggers[1]{'ammo_type'} = ReadItemId();
  $triggers[1]{'rounds_per'} = ReadSint16();
  
  print ItemCommentLine(
          ReadFixedOne(), ReadTicks(),
          'firing intensity, firing decay');
  print "\n";
  
  print "		/* idle height, bob amplitude, kick height, reload height */\n";
  print ItemLine(
          ReadFixedOne(), ReadFixedOne(), ReadFixedOne(), ReadFixedOne());
  print "		\n";
  
  print "		/* horizontal positioning.. */\n";
  print ItemLine(
          ReadFixedOne(), ReadFixedOne());
  print "\n";
  
  print "		/* collection, idle, firing, reloading shapes; shell casing, charging, charged */\n";
  print ItemLine(
          ReadWColl());
  print ItemLine(
          ReadSNone(), ReadSNone(), ReadSNone());
  print ItemLine(
          ReadSNone());
  print ItemLine(ReadSNone(), ReadSNone());
  print "\n";
  
  $triggers[0]{'ticks_per'} = ReadTicks();
  $triggers[1]{'ticks_per'} = ReadTicks();
  
  print "		/* ready/await/load/finish/powerup rounds ticks */\n";
  do {
    my $reload = ReadTicks();
    my $ready = ReadTicks();
    print ItemLine($ready, $reload, 'NONE', 'NONE', 'NONE');
  };
  print "\n";
  
  $triggers[0]{'recover_ticks'} = ReadTicks();
  $triggers[1]{'recover_ticks'} = ReadTicks();
  $triggers[0]{'charge_ticks'} = ReadTicks();
  $triggers[1]{'charge_ticks'} = ReadTicks();
  
  $triggers[0]{'recoil'} = ReadSNone();
  $triggers[1]{'recoil'} = ReadSNone();
  
  $triggers[0]{'snd_firing'} = ReadSoundId();
  $triggers[1]{'snd_firing'} = ReadSoundId();
  $triggers[0]{'snd_click'} = ReadSoundId();
  $triggers[1]{'snd_click'} = ReadSoundId();
  $triggers[0]{'snd_reload'} = $triggers[1]{'snd_reload'} = ReadSoundId();
  $triggers[0]{'snd_charge'} = $triggers[1]{'snd_charge'} = ReadSoundId();
  $triggers[0]{'snd_casing'} = ReadSoundId();
  $triggers[1]{'snd_casing'} = ReadSoundId();
  ReadPadding(4); # sound activation range
  
  $triggers[0]{'proj'} = ReadProjType();
  $triggers[1]{'proj'} = ReadProjType();
  
  $triggers[0]{'theta'} = ReadSNone();
  $triggers[1]{'theta'} = ReadSNone();

  $triggers[0]{'dx'} = ReadDx();
  $triggers[0]{'dz'} = ReadDz();
  $triggers[1]{'dx'} = ReadDx();
  $triggers[1]{'dz'} = ReadDz();

  $triggers[0]{'burst'} = ReadSNone();
  $triggers[1]{'burst'} = ReadSNone();
  
  ReadPadding(2);  # instant reload tick
  
  print "		{\n";
  for my $trigger (0..1)
  {
    my $t = $triggers[$trigger];
    print "			{\n";
    
    print "				/* rounds per magazine */\n";
    print "		" . ItemLine(
                    $t->{'rounds_per'});
    print "	\n";
    
    print "				/* Ammunition type */\n";
    print "		" . ItemLine(
                    $t->{'ammo_type'});
    print "				\n";
    
    print "				/* Ticks per round, recovery ticks, charging ticks */\n";
    print "		" . ItemLine(
                    $t->{'ticks_per'},
                    $t->{'recover_ticks'}, $t->{'charge_ticks'});
    print "				\n";
    
    print "				/* recoil magnitude */\n";
    print "		" . ItemLine(
                    $t->{'recoil'});
    print "				\n";
    
    print "				/* firing, click, charging, shell casing, reload sound */\n";
    print "		" . ItemLine(
                    $t->{'snd_firing'}, $t->{'snd_click'}, $t->{'snd_charge'},
                    $t->{'snd_casing'}, $t->{'snd_reload'}, 'NONE');
    print "				\n";
    
    print "				/* projectile type */\n";
    print "		" . ItemLine(
                    $t->{'proj'});
    print "				\n";
    
    print "				/* theta error */\n";
    print "		" . ItemLine(
                    $t->{'theta'});
    print "				\n";
    
    print "				/* dx, dz */\n";
    print "		" . ItemLine(
                    $t->{'dx'}, $t->{'dz'});
    print "				\n";
    
    print "				/* shell casing type */\n";
    print "		" . ItemLine(
                    'NONE');
    print "\n";
    
    print "				/* burst count */\n";
    print "		" . ItemLine(
                    $t->{'burst'});
    
    print "			},\n";
  }
  print "		},\n";
  
  print "	},\n\n";
}
print <<END;
};
END
warn "Ending at: " . CurOffset() . "\n";


sub ReadWColl
{
  my $res = ReadCollectionSOpt();
  return '_weapon_in_hand_collection' if $res eq '_collection_weapons_in_hand';
  return $res;
}
sub ReadDx
{
  my $res = ReadWorldOne();
  return '-(WORLD_ONE_FOURTH/6)' if $res eq '-WORLD_ONE/24';
  return '(WORLD_ONE_FOURTH/6)' if $res eq 'WORLD_ONE/24';
  return $res;
}

sub ReadDz
{
  return FormatDz(ReadSint16());
}
sub FormatDz
{
  my ($res) = @_;
  return 'NORMAL_WEAPON_DZ' if $res == 20;
  return '-NORMAL_WEAPON_DZ' if $res == -20;
  for my $i (2..10)
  {
    return "$i*NORMAL_WEAPON_DZ" if $res == 20*$i;
    return "-$i*NORMAL_WEAPON_DZ" if $res == -20*$i;
  }
  
  return $res;
}

sub ReadWFlags
{
  return ReadUint16();
}
sub ReadWClass
{
  return ReadEnum16(\@CLASSES);
}
sub ReadProjType
{
  return ReadSNone();  # M2 added shotgun near start of enums
}

