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

my @fades = qw(
	_start_cinematic_fade_in
	_cinematic_fade_in
	_long_cinematic_fade_in
	_cinematic_fade_out
	_end_cinematic_fade_out
	_fade_red
	_fade_big_red
	_fade_bonus
	_fade_bright
	_fade_long_bright
	_fade_yellow
	_fade_big_yellow
	_fade_purple
	_fade_cyan
	_fade_white
	_fade_big_white
	_fade_orange
	_fade_long_orange
	_fade_green
	_fade_long_green
	_fade_static
	_fade_negative
	_fade_big_negative
	_fade_dodge_purple
	_fade_burn_cyan
	_fade_dodge_yellow
	_fade_burn_green
  );

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
  
  print '}, /* ' . ($fades[$fadenum] || 'unknown') . " */\n";
  
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
