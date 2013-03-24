#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";

SetReadOffset(15922);
warn "Starting at: " . CurOffset() . "\n";
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * sound_pitch, delay, delay_sound not present
 * data changes too numerous to list
 *
 *****/

const struct effect_definition m1_original_effect_definitions[]=
{
END

for my $effectnum (0..37)
{
  print '	{';
  
  print join(', ',
          ReadCollectionOpt(),
          ReadUint16(),
          '_normal_frequency',
          ReadEffectFlags(),
          0,
          'NONE');
  
  print "},\n";  
}
print <<END;
};
END
warn "Ending at: " . CurOffset() . "\n";

sub ReadEffectFlags
{
  return ReadFlags16(
    [qw(
    	_end_when_animation_loops
      _end_when_transfer_animation_loops
      _sound_only
      _make_twin_visible
      _media_effect
      )]);
}
