#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";

SetReadOffset(14474);
warn "Starting at: " . CurOffset() . "\n";
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * structure same as M2
 * items through extravision are unchanged
 * repair chip, energy converter are present
 * 20 items total
 *
 *****/

static struct item_definition m1_item_definitions[]=
{
END

my @INAMES = split("\n", <<END);
Knife
pistol and ammo

fusion pistol and ammo

assault rifle, bullets and grenades


rocket launcher and ammo

invisibility, invincibility, infravision


alien weapon and ammunition

flamethrower and ammo

extravision powerup
repair chip, energy converter
END

for my $itemnum (0..19)
{
  my $name = $INAMES[$itemnum];
  print "\n	// $name\n" if $name;
  
  print "	{";
  print join(', ',
    ReadItemKind(),
    ReadSNone(), ReadSNone(),
    ReadDescriptor(),
    ReadSNone(),
    ReadEnvFlags());  
  print "},\n";
}
print <<END;
};
END
warn "Ending at: " . CurOffset() . "\n";

sub ReadItemKind
{
  return ReadEnum16(
    [qw(_weapon
        _ammunition
        _powerup
        _item
        _weapon_powerup
        _ball)]);
}

sub ReadEnvFlags
{
  return ReadFlags16(
    [qw(_environment_vacuum
        _environment_magnetic
        _environment_rebellion
        _environment_low_gravity)]);
}
