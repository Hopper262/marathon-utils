#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";



SetReadOffset(13366);
warn "Starting at: " . CurOffset() . "\n";
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * death_sound, death_action not present
 * _damage_shotgun_projectile, energy_drain,
 *   oxygen_drain, hummer_bolt not present
 *
 *****/

const struct damage_response m1_damage_response_definitions[]=
{
END

for my $dmg (0..19)
{
  print '		{';
  
  print join(', ',
             ReadDamageType(), ReadSNone(),
             ReadFadeType(), ReadSNone(),
             'NONE', 'NONE',
          );
  
  print "},\n";  
}
print <<END;
};
END
warn "Ending at: " . CurOffset() . "\n";

