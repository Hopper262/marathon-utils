#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";

SetReadOffset(16150);
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * destroyed_effect, destroyed_shape not present
 * data completely different
 *
 *****/

struct scenery_definition m1_scenery_definitions[]=
{
END

my @SNAMES = split("\n", <<END);
upright waste
sideways waste
upright cylinder
sideways cylinder
paper
comm. satellite
escape pod
bioh. crate
alien ship
dead soft BOB
dissected BOB
Pfhor dormant
empty armor
examination BOB
electrosynth
orb
Marathon
slave transport
END

for my $scenum (0..16)
{
  print "	{";
  my $flags = ReadSceneryFlags();
  if ($flags eq '0')
  {
    print join(', ',
      $flags,
      ReadDescriptor());
    die unless ReadSint16() == 0;
    die unless ReadSint16() == 0;
  }
  else
  {
    print join(', ',
      $flags,
      ReadDescriptor(),
      ReadWorldOne(), ReadWorldOne()); 
  }
  print "}, // $SNAMES[$scenum]\n";
}
print <<END;
};
END

sub ReadSceneryFlags
{
  return ReadFlags16(
    [qw(_scenery_is_solid
        _scenery_is_animated
        _scenery_can_be_destroyed)]);
}
