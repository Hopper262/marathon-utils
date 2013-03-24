#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";

SetReadOffset(3828);
warn "Starting at: " . CurOffset() . "\n";
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * multiple_shape, multiple_unusable_shape not present
 * multiple_delta_x, multiple_delta_y not present
 * only seven entries
 * position and shape changes too numerous to list
 *
 *****/

struct weapon_interface_data m1_weapon_interface_definitions[] =
{
END

my @WEAPONS = split("\n", <<END);
Mac, the knife..
Harry, the .44
Ripley, the plasma pistol.
Arnold, the assault rifle
John R., the missile launcher
???, the flame thrower
Predator, the alien shotgun
END

for my $wepnum (0..6)
{
  print '	/* ' . $WEAPONS[$wepnum] . " */\n";
  print "	{\n";
  print ItemLine(ReadItemId());
  print ItemLine(ReadDescriptor());
  print ItemLine(ReadSNone(), ReadSNone());
  print ItemLine(ReadSNone(), ReadSNone());
  print ItemLine(ReadSNone(), ReadSNone());
  print ItemLine(ReadBoolean());
  ReadPadding(1);  # boolean word alignment
  
  # ammo
  print "		{\n";
  
  for my $i (0..1)
  {
    print '			{ ';
    
    my $ammoType = ReadAmmoType();
    
    print join(', ',
      $ammoType,
      ReadSint16(), ReadSint16(),
      ReadSint16(), ReadSint16(),
      ReadSint16(), ReadSint16(),
      ($ammoType eq '_uses_bullets' ? (ReadDescriptor(), ReadDescriptor())
                                    : (ReadIntColor(), ReadIntColor())),
      ReadBoolean());
    ReadPadding(1);  # boolean word alignment
    print "},\n";
  }

  print "		},\n";
  
  ### Fill out multiple-shape info -- hardcoded in M1?
  if ($wepnum == 1)
  {
    print ItemLine(FormatDescriptor(0, 15));
    print ItemLine(FormatDescriptor(0, 9));
    print ItemLine(-97, 0);   # measured from screenshot
  }
  else
  {
    print ItemLine('UNONE', 'UNONE');
    print ItemLine(0, 0);
  }
  
  print "	},\n\n";  
}
print <<END;
};
END
warn "Ending at: " . CurOffset() . "\n";

sub ReadAmmoType
{
  return ReadEnum16(
    [qw(_unused_interface_data _uses_energy _uses_bullets)]);
}
sub ReadIntColor
{
  my $res = ReadEnum16(
    [qw(_energy_weapon_full_color _energy_weapon_empty_color)]);
  return 'UNONE' if $res eq '65535';
  return $res;
}


