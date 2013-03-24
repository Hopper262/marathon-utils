#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";

SetReadOffset(14814);
warn "Starting at: " . CurOffset() . "\n";
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * splash height not present
 * data otherwise identical to M2
 *
 *****/

const struct physics_constants m1_original_physics_models[]=
{
END

for my $recnum (0..1)
{
  print '	/* game ' . ($recnum == 0 ? 'walking' : 'running') . " */\n";
  print <<END;
	{
END
  print ItemCommentLine(
    ReadFixedOne(), ReadFixedOne(), ReadFixedOne(),
    'max forward, backward and perpendicular velocity');
  print ItemCommentLine(
    ReadFixedOne(), ReadFixedOne(), ReadFixedOne(),
    'acceleration, deceleration, airborne deceleration');
  print ItemCommentLine(
    ReadFixedOne(), ReadFixedOne(), ReadFixedOne(),
    'gravity, normal acceleration, terminal velocity');
  print ItemCommentLine(
    ReadFixedOne(),
    'external deceleration');

  print "\n";
  print ItemCommentLine(
    ReadFixedOne(), ReadFixedOne(), ReadFixedOne(), ReadFixedOne(),
    'angular acceleration, deceleration, max');
  print ItemCommentLine(
    ReadQCircle(), ReadQCircle(),
    'fast angular v, max');
  print ItemCommentLine(
    ReadQCircle(),
    'maximum elevation');
  print ItemCommentLine(
    ReadFixedOne(),
    'external angular deceleration');

  print "\n";
  print ItemCommentLine(
    ReadFixedOne(), ReadFixedOne(),
    'step delta, step amplitude');
  print ItemCommentLine(
    ReadFixedOne(), ReadFixedOne(), ReadFixedOne(), ReadFixedOne(),
    'radius, height, dead height, viewpoint height');
  print ItemCommentLine(
    'FIXED_ONE/2',
    'splash height');
  print ItemCommentLine(
    ReadFixedOne(),
    'camera separation');

  print <<END;
	},
END
}
print <<END;
};
END
warn "Ending at: " . CurOffset() . "\n";

