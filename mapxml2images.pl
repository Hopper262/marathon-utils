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
    -font       TTF font; required for annotations (default: no annotations)
    -fontsize   Text size for map annotations (default: 26)
    -nozoom     Zoom levels to fill image size (default: zoom)
    -all        Show all lines and polygons, like a map editor (default: no)
    -ignore     File of polygons to ignore when drawing levels (default: none)
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
our $FONT = undef;
our $FONTSIZE = 26;
our $ZOOM = 1;
our $SHOWALL = 0;
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
  'ignore=s' => \$OVERRIDES,
  'zoom!' => \$ZOOM,
  'all!' => \$SHOWALL,
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
      );
our %LINEWIDTH = (
      'solid' => $LINEW,
      'elevation' => $LINEW/2,
      'annotation' => $FONTSIZE,
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

my @ignore_list;
if (defined $OVERRIDES)
{
  my $overfh;
  open($overfh, '<', $OVERRIDES) or die;
  while (my $line = <$overfh>)
  {
    chomp $line;
    next unless $line =~ s/^(\d+):\s+//;
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

our ($points, $lines, $sides, $polys, $platforms, $notes, $liquids, $ignores);
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
  $ignores = $ignore_list[$levelnum] || {};
  
  # scale
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
    my $xscale = $imgw / $worldw;
    my $yscale = $imgh / $worldh;
    my $scale = ($xscale < $yscale) ? $xscale : $yscale;
    my $adjx = $cenx + ($WIDTH * 0.5 / $scale);
    my $adjy = $ceny + ($HEIGHT * 0.5 / $scale);
    
    for my $pt (@$points)
    {
      $pt->{'x'} += $adjx;
      $pt->{'x'} *= $scale;
      $pt->{'y'} += $adjy;
      $pt->{'y'} *= $scale;
    }
    for my $note (@$notes)
    {
      $note->{'location_x'} += $adjx;
      $note->{'location_x'} *= $scale;
      $note->{'location_y'} += $adjy;
      $note->{'location_y'} *= $scale;
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
  
  if ($fface)
  {
    for my $note (@$notes)
    {
      $cr->move_to($note->{'location_x'}, $note->{'location_y'});
      $cr->set_source_rgb(@{ $COLORS{'annotation'} });
      $cr->show_text($note->{'content'});
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
