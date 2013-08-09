#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/enum.subs";

SetReadOffset(3218);
warn "Starting at: " . CurOffset() . "\n";
print <<END;
/*****
 * Marathon compatibility notes:
 *
 * _fade_flicker_negative was not present
 * soft-tint fades were not present
 * flags were different; one unknown flag was used on 3 cinematic fades
 * no priority; M2 uses it on _fade_long_bright
 * _fade_long_green was green; changed to purple for M2
 *
 *****/

static struct fade_definition m1_fade_definitions[]=
{
END

for my $fadenum (0..26)
{
  print '	{';
  
  print join(', ',
          ReadFadeTable(),
          ReadRGB(),
          ReadFixedOne(),
          ReadFixedOne(),
          ReadMTicks(),
          ReadFadeFlags(),
          0);
  ReadUint8();  # flag set on cinematic fades - no M2 equivalent
  
  print '}, /* ' . FormatFadeType($fadenum) . " */\n";
  
  if ($fadenum == 22)
  {
    print "	/* _fade_flicker_negative not present in Marathon 1 */\n";
  }
}
print <<END;
};
END
warn "Ending at: " . CurOffset() . "\n";

sub ReadFadeFlags
{
  return ReadFlags8(
    [qw(_full_screen_flag _random_transparency_flag)]);
}
sub ReadFadeTable
{
  return ReadEnum32(
    { 906 => 'tint_color_table',
      914 => 'randomize_color_table',
      922 => 'negate_color_table',
      930 => 'dodge_color_table',
      938 => 'burn_color_table' });
}
