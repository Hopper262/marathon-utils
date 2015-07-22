#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use Cairo ();
use Font::FreeType ();
use XML::Simple ();
use Getopt::Long ();
use Pod::Usage ();

=head1 NAME

mapxml2images.pl - Generate map previews for Marathon levels

=head1 SYNOPSIS

  mapxml2images.pl [options] < <map.xml>
  
  Options:
    -format     Image format: "png", "pdf", or "svg" (default: png)
    -width      Image width, in pixels/points (default: 2000)
    -height     Image height, in pixels/points (default: 1600)
    -margin     Pixels/points from edge to map point (default: 60)
    -dir        Output directory for files (default: working directory)
    -linewidth  Width of thick lines; thin lines are half width (default: 3)
    -font       TTF font; required for annotations or legend (default: none)
    -fontsize   Text size for map annotations and legend (default: 26)
    -mark       Show points of interest, like terminals (default: no)
    -marksize   Radius of PoI marks (default: 10)
    -legend     Explain PoI marks at bottom of image (default: no)
    -grid       Show grid behind map (default: no)
    -gridsize   Spacing between grid lines, in WU (default: 4)
    -all        Show all lines and polygons, like a map editor (default: no)
    -ignore     File of polygons to ignore when drawing levels (default: none)
    -nopoly     Hide polygons (default: show)
    -noline     Hide lines (default: show)
    -noanno     Hide annotations (default: show)
    -zoom       Zoom levels to fill image size (default: no)
    -solid      Draw black background (default: clear background)
    -html       Output "preview.html" page (default: no)
    -scales     Output "scale.txt" information about images (default: no)
    -help, -?   Print this help message

=cut

# config
our $FORMAT = 'png';
our $WIDTH = 2000;
our $HEIGHT = 1600;
our $MARGIN = 60;
our $OUTDIR = '.';
our $LINEW = 3;
our $MARK = 0;
our $LEGEND = 0;
our $RADIUS = 10;
our $FONT = undef;
our $FONTSIZE = 26;
our $GRID = 0;
our $GRIDSIZE = 4;
our $POLY = 1;
our $LINE = 1;
our $ANNO = 1;
our $ZOOM = 0;
our $SHOWALL = 0;
our $SOLID = 0;
our $OVERRIDES = undef;
our $HTML = 0;
our $SCALES = 0;
our $HELP = 0;
Getopt::Long::Configure('auto_abbrev');
Getopt::Long::GetOptions(
  'format=s' => \$FORMAT,
  'width=i' => \$WIDTH,
  'height=i' => \$HEIGHT,
  'margin=f' => \$MARGIN,
  'dir=s' => \$OUTDIR,
  'linewidth=f' => \$LINEW,
  'font=s' => \$FONT,
  'fontsize=f' => \$FONTSIZE,
  'mark!' => \$MARK,
  'marksize=f' => \$RADIUS,
  'legend!' => \$LEGEND,
  'grid!' => \$GRID,
  'gridsize=f' => \$GRIDSIZE,
  'ignore=s' => \$OVERRIDES,
  'poly!' => \$POLY,
  'line!' => \$LINE,
  'anno!' => \$ANNO,
  'zoom!' => \$ZOOM,
  'all!' => \$SHOWALL,
  'solid!' => \$SOLID,
  'html!' => \$HTML,
  'scales!' => \$SCALES,
  'help|?' => \$HELP,
  ) or Pod::Usage::pod2usage(2);
Pod::Usage::pod2usage(1) if $HELP;
Pod::Usage::pod2usage(1) if $FORMAT ne 'png' && $FORMAT ne 'pdf' && $FORMAT ne 'svg';
Pod::Usage::pod2usage(1) if $WIDTH < 1 || $HEIGHT < 1 || $FONTSIZE < 1;
Pod::Usage::pod2usage(1) if $LINEW < 0;
Pod::Usage::pod2usage(1) if defined($FONT) && !-f $FONT;
Pod::Usage::pod2usage(1) if defined($OVERRIDES) && !-f $OVERRIDES;
Pod::Usage::pod2usage(1) if defined($OUTDIR) && -e $OUTDIR && !-d $OUTDIR;
$OUTDIR = '.' unless defined($OUTDIR);
mkdir $OUTDIR unless -d $OUTDIR;
Pod::Usage::pod2usage(1) unless -d $OUTDIR;

our $TWOPI = 8 * atan2(1, 1);
our %COLORS = (
      'plain' => [ 0, 47/255, 0 ],
      'platform' => [ 117/255, 0, 0 ],
      'water' => [ 14/255, 37/255, 63/255 ],
      'lava' => [ 76/255, 27/255, 0 ],
      'sewage' => [ 70/255, 90/255, 0 ],
      'jjaro' => [ 70/255, 90/255, 0 ],
      'pfhor' => [ 137/255, 0, 137/255 ],
      'minor_ouch' => [ 76/255, 27/255, 0 ],
      'major_ouch' => [ 137/255, 0, 137/255 ],
      'teleporter' => [ 0, 47/255, 0 ],
      'hill' => [ 0, 47/255, 0 ],
      'line_solid' => [ 0, 255/255, 0 ],
      'line_elevation' => [ 0, 157/255, 0 ],
      'annotation' => [ 0, 255/255, 0 ],
      'landscape' => [ 37/255, 0, 37/255 ],
      'shield_refuel' => [ 1, 0, 0 ],
      'double_shield_refuel' => [ 1, 1, 0 ],
      'triple_shield_refuel' => [ 1, 0, 1 ],
      'pattern_buffer' => [ 1, 0.5, 0.25 ],
      'computer_terminal' => [ 1, 1, 1 ],
      'oxygen_refuel' => [ 0, 1, 1 ],
      'player_start' => [ 0, 0.5, 1 ],
      'block' => [ 0, 0, 0 ],
      'grid' => [ 37/255, 37/255, 37/255 ],
      'background' => [ 0, 0, 0 ],
      );
our %LINEWIDTH = (
      'solid' => $LINEW,
      'elevation' => $LINEW/2,
      'mark' => $RADIUS/2,
      'markblock' => $RADIUS*3/4,
      'annotation' => $FONTSIZE,
      'grid' => $LINEW/1.5,
      );

# setup
my $xml = XML::Simple::XMLin('-', 'KeyAttr' => [], 'ForceArray' => 1);
Pod::Usage::pod2usage(1) unless $xml;
my $entries = $xml->{'entry'};
Pod::Usage::pod2usage(1) unless $entries;

my $fface;
if (defined $FONT)
{
  my $ft_face = Font::FreeType->new()->face($FONT);
  $fface = Cairo::FtFontFace->create($ft_face) if $ft_face;
}

our $M1_MODE = ($xml->{'wadinfo'}[0]{'type'} < 2);
our @PANEL_TYPES;
if ($M1_MODE)
{
  @PANEL_TYPES = qw(
      oxygen_refuel shield_refuel double_shield_refuel
      triple_shield_refuel light_switch platform_switch
      pattern_buffer tag_switch computer_terminal tag_switch
      double_shield_refuel triple_shield_refuel platform_switch
      pattern_buffer
    );
}
else
{
  @PANEL_TYPES = qw(
      oxygen_refuel shield_refuel double_shield_refuel tag_switch
      light_switch platform_switch tag_switch pattern_buffer
      computer_terminal tag_switch

      shield_refuel double_shield_refuel triple_shield_refuel
      light_switch platform_switch tag_switch pattern_buffer
      computer_terminal oxygen_refuel tag_switch tag_switch

      shield_refuel double_shield_refuel triple_shield_refuel
      light_switch platform_switch tag_switch pattern_buffer
      computer_terminal oxygen_refuel tag_switch tag_switch

      shield_refuel double_shield_refuel triple_shield_refuel
      light_switch platform_switch tag_switch pattern_buffer
      computer_terminal oxygen_refuel tag_switch tag_switch

      shield_refuel double_shield_refuel triple_shield_refuel
      light_switch platform_switch tag_switch pattern_buffer
      computer_terminal oxygen_refuel tag_switch tag_switch
    );
}
our @PANELS = qw(computer_terminal pattern_buffer
                 shield_refuel double_shield_refuel triple_shield_refuel
                 oxygen_refuel);
our %PANEL_LABELS = (
  'oxygen_refuel' => 'Oxygen',
  'shield_refuel' => '1X shields',
  'double_shield_refuel' => '2X shields',
  'triple_shield_refuel' => '3X shields',
  'pattern_buffer' => 'Save',
  'computer_terminal' => 'Terminal',
  'player_start' => 'Player start',
  );

my @ignore_list;
if (defined $OVERRIDES)
{
  my $overfh;
  open($overfh, '<', $OVERRIDES) or die;
  while (my $line = <$overfh>)
  {
    chomp $line;
    next unless $line =~ s/^\s*(\d+):\s+//;
    my $levnum = $1;
    
    my %hashed;
    for my $poly (split(/\s+/, $line))
    {
      if ($poly =~ /^(\d+)-(\d+)$/)
      {
        for my $index ($1..$2)
        {
          $hashed{$index} = 1;
        }
      }
      elsif ($poly =~ /^(\d+)$/)
      {
        $hashed{$1} = 1;
      }
      else
      {
        last;  # stop processing at unrecognized data
      }
    }
    $ignore_list[$levnum] = { %hashed };
  }
}

my $scalefh;
if ($SCALES)
{
  open($scalefh, '>', "$OUTDIR/scale.txt") or die;
  print $scalefh sprintf("%d %d\n", $WIDTH, $HEIGHT);
}

my $htmlfh;
if ($HTML)
{
  open($htmlfh, '>', "$OUTDIR/preview.html") or die;
  print $htmlfh <<END;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en"><head>
<title>Level Preview</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<style type="text/css">
body {
  background: black;
  color: #0f0;
  text-align: center;
  font-family: Monaco, ProFont;
}
img {
  width: @{[ int($WIDTH/2) ]}px;
  height: @{[ int($HEIGHT/2) ]}px;
}
</style>
</head>
<body>
END
}

our ($points, $lines, $sides, $polys, $platforms, $notes, $liquids, $objects, $ignores);
for my $levelnum (0..(scalar(@$entries)-1))
{
  my $level = $entries->[$levelnum];
  my $infochunk = FindChunk($level, 'Minf');
  next unless $infochunk && $infochunk->[0];
  my $levelname = $infochunk->[0]{'content'} || '(unnamed)';
  warn "Processing $levelnum. $levelname\n";
  
  my $outw = int($WIDTH / 2);
  my $outh = int($HEIGHT / 2);
  print $htmlfh qq(<h3>$levelnum. $levelname</h3><p><img src="$levelnum.$FORMAT"></p>\n) if $htmlfh;
  
  $points = FindChunk($level, 'EPNT') || FindChunk($level, 'PNTS');
  $lines = FindChunk($level, 'LINS');
  $sides = FindChunk($level, 'SIDS');
  $polys = FindChunk($level, 'POLY');
  $platforms = FindChunk($level, 'plat') || FindChunk($level, 'PLAT');
  $notes = FindChunk($level, 'NOTE') || [];
  $liquids = FindChunk($level, 'medi') || [];
  $objects = FindChunk($level, 'OBJS') || [];
  $ignores = $ignore_list[$levelnum] || {};
  FixSides();
  
  # scale
  my $pt_adj;
  do {
    my ($minx, $maxx, $miny, $maxy) = (-32768, 32767, -32768, 32767);
    if ($ZOOM)
    {
      ($minx, $maxx, $miny, $maxy) = (32767, -32768, 32767, -32768);
      for my $poly (@$polys)
      {
        next if HiddenPoly($poly);
        for my $i (0..($poly->{'vertex_count'} - 1))
        {
          my ($x, $y) = Coords($poly->{"endpoint_index_$i"});
          $minx = $x if $x < $minx;
          $maxx = $x if $x > $maxx;
          $miny = $y if $y < $miny;
          $maxy = $y if $y > $maxy;
        }
      }
    }
    
    my $worldw = $maxx - $minx;
    my $worldh = $maxy - $miny;
    my $cenx = 0;
    my $ceny = 0;
    if ($ZOOM)
    {
      $cenx = 0 - ($worldw/2 + $minx);
      $ceny = 0 - ($worldh/2 + $miny);
    }
    
    my $imgw = $WIDTH - 2*$MARGIN;
    my $imgh = $HEIGHT - 2*$MARGIN;
    if ($LEGEND && $fface)
    {
      $imgh -= 2*$FONTSIZE;
    }
    my $xscale = $imgw / $worldw;
    my $yscale = $imgh / $worldh;
    my $scale = ($xscale < $yscale) ? $xscale : $yscale;
    my $adjx = $cenx + (($MARGIN + $imgw/2) / $scale);
    my $adjy = $ceny + (($MARGIN + $imgh/2) / $scale);
    
    $pt_adj = sub {
      my ($x, $y) = @_;
      return (($x + $adjx) * $scale, ($y + $adjy) * $scale);
    };

    for my $pt (@$points)
    {
      ($pt->{'x'}, $pt->{'y'}) =
        $pt_adj->($pt->{'x'}, $pt->{'y'});
    }
    for my $note (@$notes)
    {
      ($note->{'location_x'}, $note->{'location_y'}) =
        $pt_adj->($note->{'location_x'}, $note->{'location_y'});
    }
    for my $obj (@$objects)
    {
      ($obj->{'location_x'}, $obj->{'location_y'}) =
        $pt_adj->($obj->{'location_x'}, $obj->{'location_y'});
    }
    print $scalefh sprintf("%d %d %f  # %s\n",
                           $adjx, $adjy, $scale, $levelname) if $scalefh;
  };

  my $surface;
  if ($FORMAT eq 'png')
  {
    $surface = Cairo::ImageSurface->create('argb32', $WIDTH, $HEIGHT);
  }
  elsif ($FORMAT eq 'pdf')
  {
    $surface = Cairo::PdfSurface->create("$OUTDIR/$levelnum.pdf", $WIDTH, $HEIGHT);
  }
  elsif ($FORMAT eq 'svg')
  {
    $surface = Cairo::SvgSurface->create("$OUTDIR/$levelnum.svg", $WIDTH, $HEIGHT);
  }
  my $cr = Cairo::Context->create($surface);
  $cr->set_line_cap("round");
  if ($fface)
  {
    $cr->set_font_face($fface);
    $cr->set_font_size($FONTSIZE);
  }
  
  if ($SOLID)
  {
    $cr->rectangle(0, 0, $WIDTH, $HEIGHT);
    $cr->set_source_rgb(@{ $COLORS{'background'} });
    $cr->fill();
  }
  
  if ($GRID && $GRIDSIZE > 0.001)
  {
    for (my $i = 0; $i <= 32/$GRIDSIZE; $i++)
    {
      my $incr = $GRIDSIZE * 1024 * $i;

      $cr->move_to($pt_adj->($incr, -32768));
      $cr->line_to($pt_adj->($incr, 32768));
      $cr->move_to($pt_adj->(-32768, $incr));
      $cr->line_to($pt_adj->(32768, $incr));
      if ($incr > 0)
      {
        $cr->move_to($pt_adj->(-$incr, -32768));
        $cr->line_to($pt_adj->(-$incr, 32768));
        $cr->move_to($pt_adj->(-32768, -$incr));
        $cr->line_to($pt_adj->(32768, -$incr));
      }
    }
    $cr->set_source_rgb(@{ $COLORS{'grid'} });
    $cr->set_line_width($LINEWIDTH{'grid'});
    $cr->stroke();
  }
  
  if ($POLY)
  {
    $cr->set_antialias('none');
    for my $poly (@$polys)
    {
      next if HiddenPoly($poly) && !$SHOWALL;
      my $color = $COLORS{'plain'};
      $color = $COLORS{'landscape'} if $SHOWALL && LandscapedPoly($poly);
      $color = $COLORS{'teleporter'} if $poly->{'type'} == 10;    
      if ($M1_MODE)
      {
        $color = $COLORS{'minor_ouch'} if $poly->{'type'} == 3;
        $color = $COLORS{'major_ouch'} if $poly->{'type'} == 4;
      }
      else
      {
        $color = $COLORS{'hill'} if $poly->{'type'} == 3;
        $color = $COLORS{'minor_ouch'} if $poly->{'type'} == 19;
        $color = $COLORS{'major_ouch'} if $poly->{'type'} == 20;
        if ($poly->{'media_index'} >= 0)
        {
          my $media = $liquids->[$poly->{'media_index'}];
          if ($poly->{'floor_height'} < $media->{'low'})
          {
            $color = $COLORS{'water'} if $media->{'type'} == 0;
            $color = $COLORS{'lava'} if $media->{'type'} == 1;
            $color = $COLORS{'pfhor'} if $media->{'type'} == 2;
            $color = $COLORS{'sewage'} if $media->{'type'} == 3;
            $color = $COLORS{'jjaro'} if $media->{'type'} == 4;
          }
        }
      }
      $color = $COLORS{'platform'} if $poly->{'type'} == 5 && !SecretPoly($poly);
      $cr->set_source_rgb(@$color);

      $cr->move_to(Coords($poly->{'endpoint_index_0'}));
      for my $i (1..($poly->{'vertex_count'} - 1))
      {
        $cr->line_to(Coords($poly->{'endpoint_index_' . $i}));
      }
      $cr->fill();
    }
    $cr->set_antialias('default');
  }
  
  if ($LINE)
  {
    # Draw elevation lines before solid ones.
    # This differs from Bungie's engine, but
    # gives nicer-looking results.
    for my $line (@$lines)
    {
      my $cw = FindPoly($line->{'cw_poly'});
      my $ccw = FindPoly($line->{'ccw_poly'});
      unless ($SHOWALL)
      {
        next unless ($cw && !UnseenPoly($cw) && !IgnoredPoly($cw)) ||
                    ($ccw && !UnseenPoly($ccw) && !IgnoredPoly($ccw));
      }
  
      my $solid = SolidLine($line);
      my $landscaped = LandscapedLine($line);
  
      my $draw = 0;
      if ($SHOWALL)
      {
        $draw = !$solid;
      }
      elsif (!$solid && !$landscaped)
      {
        $draw = 1 if $cw->{'floor_height'} != $ccw->{'floor_height'};
      }
      elsif ($solid && $landscaped)
      {
        $draw = 1 if ((!$cw || $cw->{'floor_transfer_mode'} != 9) &&
                      (!$ccw || $ccw->{'floor_transfer_mode'} != 9));
      }
    
      if ($draw)
      {
        $cr->move_to(Coords($line->{'endpoint1'}));
        $cr->line_to(Coords($line->{'endpoint2'}));
      }
    }
    $cr->set_source_rgb(@{ $COLORS{'line_elevation'} });
    $cr->set_line_width($LINEWIDTH{'elevation'});
    $cr->stroke();

    for my $line (@$lines)
    {
      my $cw = FindPoly($line->{'cw_poly'});
      my $ccw = FindPoly($line->{'ccw_poly'});
      unless ($SHOWALL)
      {
        next unless ($cw && !UnseenPoly($cw) && !IgnoredPoly($cw)) ||
                    ($ccw && !UnseenPoly($ccw) && !IgnoredPoly($ccw));
      }
    
      my $solid = SolidLine($line);
      my $landscaped = LandscapedLine($line);
  
      if ($solid && ($SHOWALL || !$landscaped))
      {
        $cr->move_to(Coords($line->{'endpoint1'}));
        $cr->line_to(Coords($line->{'endpoint2'}));
      }
    }
    $cr->set_source_rgb(@{ $COLORS{'line_solid'} });
    $cr->set_line_width($LINEWIDTH{'solid'});
    $cr->stroke();  
  }
  
  if ($ANNO && $fface)
  {
    for my $note (@$notes)
    {
      my $text = $note->{'content'};
      next unless defined($text) && length($text);
      utf8::decode($text);
      next if HiddenPoly($polys->[$note->{'polygon_index'}]);
      $cr->move_to($note->{'location_x'}, $note->{'location_y'});
      $cr->set_source_rgb(@{ $COLORS{'annotation'} });
      $cr->show_text($text);
    }
  }
  
  if ($MARK)
  {
    my $starttype = 'player_start';
    my %marks = map { $_ => [] } (@PANELS, $starttype);
    
    for my $side (@$sides)
    {
      if ($side->{'flags'} & 0x2)
      {
        my $poly = $polys->[$side->{'poly'}];
        next if HiddenPoly($poly);
        my $line = $lines->[$side->{'line'}];
        my ($x1, $y1) = Coords($line->{'endpoint1'});
        my ($x2, $y2) = Coords($line->{'endpoint2'});
        my ($cx, $cy) = (($x1 + $x2)/2, ($y1 + $y2)/2);
       
        my $type = $PANEL_TYPES[$side->{'panel_type'}];
        push(@{ $marks{$type} }, [ $cx, $cy ]);
      }
    }
    for my $obj (@$objects)
    {
      next unless $obj->{'type'} == 3;
      next if HiddenPoly($polys->[$obj->{'polygon_index'}]);
      push(@{ $marks{$starttype} },
            [ $obj->{'location_x'}, $obj->{'location_y'},
              $obj->{'facing'} * $TWOPI / 512 ]);
    }
    
    my $legend_width = 0;
    my @used_legends;
    for my $ptype ($starttype)
    {
      my $refs = $marks{$ptype};
      next unless $refs && scalar @$refs;
      for my $pos (@$refs)
      {
        my ($cx, $cy, $facing) = @$pos;
        $cr->save();
        $cr->translate($cx, $cy);
        $cr->rotate($facing + $TWOPI/4);
        $cr->move_to(0, 0 - $RADIUS);
        $cr->line_to($RADIUS/2, $RADIUS);
        $cr->line_to(-$RADIUS/2, $RADIUS);
        $cr->close_path();
        $cr->restore();
        
        $cr->set_source_rgb(@{ $COLORS{'block'} });
        $cr->set_line_width($LINEWIDTH{'markblock'});
        $cr->stroke_preserve();
        $cr->set_source_rgb(@{ $COLORS{$starttype} });
        $cr->set_line_width($LINEWIDTH{'mark'});
        $cr->stroke_preserve();
        $cr->fill();
      }
      
      push(@used_legends, $starttype);
      my $extents = $cr->text_extents($PANEL_LABELS{$starttype});
      $legend_width += $extents->{'width'} + $RADIUS*10;      
    }

    for my $ptype (@PANELS)
    {
      my $refs = $marks{$ptype};
      next unless $refs && scalar @$refs;
      for my $pos (@$refs)
      {
        my ($cx, $cy) = @$pos;
        $cr->move_to($cx + $RADIUS, $cy);
        $cr->arc($cx, $cy, $RADIUS, 0, $TWOPI);
      }
      $cr->set_source_rgb(@{ $COLORS{'block'} });
      $cr->set_line_width($LINEWIDTH{'markblock'});
      $cr->stroke_preserve();
      $cr->set_source_rgb(@{ $COLORS{$ptype} });
      $cr->set_line_width($LINEWIDTH{'mark'});
      $cr->stroke();

      push(@used_legends, $ptype);
      my $extents = $cr->text_extents($PANEL_LABELS{$ptype});
      $legend_width += $extents->{'width'} + $RADIUS*10;      
    }    
    
    my $fextents = $cr->font_extents();
    my ($fasc, $fdesc) = ($fextents->{'ascent'}, $fextents->{'descent'});    
    
    my $legend_x = ($WIDTH - $legend_width)/2 + $RADIUS*2.5;
    my $legend_y = $HEIGHT - ($FONTSIZE*2 - $fasc - $fdesc)/2 - $fdesc;
    for my $ptype (@used_legends)
    {
      my ($mx, $my) = ($legend_x + $RADIUS*2, $legend_y - $RADIUS);
      if ($ptype eq $starttype)
      {
        $cr->move_to($mx, $my - $RADIUS);
        $cr->line_to($mx + $RADIUS/2, $my + $RADIUS);
        $cr->line_to($mx - $RADIUS/2, $my + $RADIUS);
        $cr->close_path();
        $legend_x += $RADIUS*5;
       
        $cr->set_source_rgb(@{ $COLORS{'block'} });
        $cr->set_line_width($LINEWIDTH{'markblock'});
        $cr->stroke_preserve();
        $cr->set_source_rgb(@{ $COLORS{$ptype} });
        $cr->set_line_width($LINEWIDTH{'mark'});
        $cr->stroke_preserve();
        $cr->fill();
      }
      else
      {
        $cr->move_to($mx + $RADIUS, $my);
        $cr->arc($mx, $my, $RADIUS, 0, $TWOPI);
        $legend_x += $RADIUS*5;
      
        $cr->set_source_rgb(@{ $COLORS{'block'} });
        $cr->set_line_width($LINEWIDTH{'markblock'});
        $cr->stroke_preserve();
        $cr->set_source_rgb(@{ $COLORS{$ptype} });
        $cr->set_line_width($LINEWIDTH{'mark'});
        $cr->stroke();
      }
      
      my $label = $PANEL_LABELS{$ptype};
      $cr->move_to($legend_x, $legend_y);
      $cr->show_text($label);
      my $extents = $cr->text_extents($label);
      $legend_x += $extents->{'width'} + $RADIUS*5;      
    }
  }
  
  $cr->show_page();
  if ($FORMAT eq 'png')
  {
    $surface->write_to_png("$OUTDIR/$levelnum.png");
  }
}

print $htmlfh "</body></html>\n" if $htmlfh;
exit;

sub FindChunk
{
  my ($level, $chunkname) = @_;
  
  for my $chunk (@{ $level->{'chunk'} })
  {
    if ($chunk->{'type'} eq $chunkname)
    {
      for my $key (keys %$chunk)
      {
        next if $key eq 'type';
        next if $key eq 'size';
        return $chunk->{$key};
      }
    }
  }
  return undef;
}

sub FixSides
{
  for my $line (@$lines)
  {
    for my $dir ('cw', 'ccw')
    {
      my $poly_index = $line->{$dir . '_poly'};
      my $side_index = $line->{$dir . '_side'};
      if ($poly_index >= 0 && $side_index >= 0)
      {
        my $side = $sides->[$side_index];
        $side->{'line'} = $line->{'index'};
        $side->{'poly'} = $poly_index;
      }
    }
  }
}

sub FindPoly
{
  my ($index) = @_;
  return undef if $index < 0;
  return $polys->[$index];
}

sub LandscapedPoly
{
  my ($poly) = @_;
  return $poly->{'floor_transfer_mode'} == 9 &&
         $poly->{'ceiling_transfer_mode'} == 9;
}
sub UnseenPoly
{
  my ($poly) = @_;
  return $poly->{'type'} != 5 &&
         $poly->{'floor_height'} == $poly->{'ceiling_height'};
}
sub IgnoredPoly
{
  my ($poly) = @_;
  return $ignores->{$poly->{'index'}};
}
sub HiddenPoly
{
  my ($poly) = @_;
  return LandscapedPoly($poly) || UnseenPoly($poly) || IgnoredPoly($poly);
}

sub Coords
{
  my ($index) = @_;
  my $pt = $points->[$index];
  return ($pt->{'x'}, $pt->{'y'});
}

sub SolidLine
{
  my ($line) = @_;
  return $line->{'flags'} & 0x4000 ||
         $line->{'cw_poly'} < 0 ||  # work around bad maps
         $line->{'ccw_poly'} < 0 ||
         $polys->[$line->{'cw_poly'}]->{'type'} == 5 ||
         $polys->[$line->{'ccw_poly'}]->{'type'} == 5;
}

sub LandscapedLine
{
  my ($line) = @_;
  return (($line->{'cw_side'} >= 0 &&
           $sides->[$line->{'cw_side'}]->{'primary_transfer'} == 9) ||
          ($line->{'ccw_side'} >= 0 &&
           $sides->[$line->{'ccw_side'}]->{'primary_transfer'} == 9));
}

sub SecretPoly
{
  my ($poly) = @_;
  
  return 0 unless $poly->{'type'} == 5;
  my $plat;
  if ($M1_MODE)
  {
    for my $p (@$platforms)
    {
      if ($p->{'polygon_index'} == $poly->{'index'})
      {
        $plat = $p;
        last;
      }
    }
  }
  else
  {
    $plat = $platforms->[$poly->{'permutation'}];
  }
  return 0 unless $plat;
  return $plat->{'static_flags'} & 0x2000000;
}
