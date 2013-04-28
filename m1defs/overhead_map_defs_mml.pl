#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/mml.subs";

SetReadOffset(7460);
warn "Starting at: " . CurOffset() . "\n";

my (@colors, @fonts, @lines);

# Font info was moved around, so there's some guessing here
push(@colors, ReadIndexedColor16(16), ReadIndexedColor16(17));

my $map_font_id = ReadSint16();
my $map_font_style = ReadUint16();
for my $i (0..3)
{
  push(@fonts, {
          'index' => $i,
          'file' => '#' . $map_font_id,
          'style' => $map_font_style,
          'size' => ReadSint16(),
        });
}
push(@fonts, {
        'index' => 4,
        'file' => '#' . $map_font_id,
        'style' => 0,
        'size' => $fonts[3]{'size'},
      });

# eight entity_definitions, all matching M2's
for my $i (0..7)
{
  my ($front, $rear, $rear_theta) = (ReadSint16(), ReadSint16(), ReadSint16());
}

# thing_definitions
# funny indexing because LP changed them; thanks :P
# only color is MML editable
for my $i (0, 2, 1, 3, 4)
{
  push(@colors, ReadIndexedColor16(11 + $i));
  my $shape = ReadSint16();
  my @radii = (ReadSint16(), ReadSint16(), ReadSint16(), ReadSint16());
  
}

# line_definitions
for my $i (0..2)
{
  push(@colors, ReadIndexedColor16(8 + $i));
  for my $j (0..3)
  {
    push(@lines, {
            'type' => $i,
            'scale' => $j,
            'width' => ReadSint16(),
          });
  }
}

# polygon colors - Marathon only colors platforms and teleporters
my $plain_color = ReadIndexedColor16(0);
push(@colors, { %$plain_color },
              ReadIndexedColor16(1));

# replace ouch colors with plain
$plain_color->{'index'} = 19;
push(@colors, { %$plain_color });
$plain_color->{'index'} = 20;
push(@colors, { %$plain_color });

# teleporter color
push(@colors, ReadIndexedColor16(21));

warn "Ending at: " . CurOffset() . "\n";
print FormatMML({ 'overhead_map' => {
                    'color' => \@colors,
                    'line' => \@lines,
                    'font' => \@fonts,
                  } });

sub ReadFadeTable
{
  my %lookup = (
    906 => 0,
    914 => 1,
    922 => 2,
    930 => 3,
    938 => 4,
    );
  
  return $lookup{ ReadUint32() };
}
