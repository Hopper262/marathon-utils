#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use Cairo ();
use Font::FreeType ();
use XML::Simple ();
use MIME::Base64 ();
use Encode ();
use Time::Format ();
use Getopt::Long ();
use Pod::Usage ();
use Carp ();
$SIG{__DIE__} = sub { Carp::confess(@_) };


=head1 NAME

term.pl - Generate Marathon terminals

=head1 SYNOPSIS

  term.pl [options] < <map.xml>
  
  Options:
    -format     Image format: "png", "pdf", or "svg" (default: png)
    -width      Image width, in pixels/points (default: 640)
    -dir        Output directory for files (default: working directory)
    -images     Where to find "PICT_1500.png" images (default: working directory)
    -config     Configuration file for fonts and MML (default: 'config.ph')
    -help, -?   Print this help message

=cut

# config
our $FORMAT = 'png';
our $WIDTH = 640;
our $OUTDIR = '.';
our $IMGDIR = '.';
our $CONFIG = 'config.ph';
our $HELP = 0;
Getopt::Long::Configure('auto_abbrev');
Getopt::Long::GetOptions(
  'format=s' => \$FORMAT,
  'width=i' => \$WIDTH,
  'dir=s' => \$OUTDIR,
  'images=s' => \$IMGDIR,
  'config=s' => \$CONFIG,
  'help|?' => \$HELP,
  ) or Pod::Usage::pod2usage(2);
  
Pod::Usage::pod2usage(1) if $HELP;
Pod::Usage::pod2usage(1) if $FORMAT ne 'png' && $FORMAT ne 'pdf' && $FORMAT ne 'svg';
Pod::Usage::pod2usage(1) if $WIDTH < 1;
Pod::Usage::pod2usage(1) unless -d $IMGDIR;

Pod::Usage::pod2usage(1) if defined($OUTDIR) && -e $OUTDIR && !-d $OUTDIR;
mkdir $OUTDIR unless -d $OUTDIR;
Pod::Usage::pod2usage(1) unless -d $OUTDIR;

Pod::Usage::pod2usage(1) if defined($CONFIG) && !-f $CONFIG;
Pod::Usage::pod2usage(1) unless require $CONFIG;

our ($MODE, %rects, %colors, @text_colors, %strings, @font_faces, %metrics);
our $HEIGHT = $rects{'screen'}{'h'} * $WIDTH/$rects{'screen'}{'w'};

our %groups = IndexedHash(qw(
  logon unfinished success failure information end
  interlevel_teleport intralevel_teleport
  checkpoint sound movie track pict logoff
  camera static tag));
our %styles = ( 'bold' => 1, 'italic' => 2, 'underline' => 4 );
our %flags = ( 'right' => 1, 'center' => 2, 'vcenter' => 4 );

our @fonts;
do {
  # The loading order is odd to force Font::FreeType and Cairo to play nice.
  my $ft = Font::FreeType->new();
  for my $file (@font_faces)
  {
    if ($file =~ /\.ttf/)
    {
      push(@fonts, { 'ftface' => $ft->face($file) });
    }
    else
    {
      push(@fonts, { 'textfile' => $file });
    }
  }

  my $dummy = DummyImage();
  my $fsize = $metrics{'size_' . $FORMAT} || $metrics{'size'};
  for my $finfo (@fonts)
  {
    $finfo->{'size'} = $fsize;
    if ($finfo->{'ftface'})
    {
      $finfo->{'face'} = Cairo::FtFontFace->create($finfo->{'ftface'});
      MeasureCairoFont($finfo, $dummy);
    }
    elsif ($finfo->{'textfile'})
    {
      LoadTextFont($finfo);
    }
  }
};


my $xml = XML::Simple::XMLin('-', 'KeyAttr' => [], 'ForceArray' => 1);
Pod::Usage::pod2usage(1) unless $xml;
my $entries = $xml->{'entry'};
Pod::Usage::pod2usage(1) unless $entries;
for my $levelnum (0..(scalar(@$entries)-1))
{
  my $level = $entries->[$levelnum];
  my $infochunk = FindChunk($level, 'Minf');
  next unless $infochunk && $infochunk->[0];
  my $levelname = $infochunk->[0]{'content'} || '(unnamed)';
  warn "Processing $levelnum. $levelname\n";

  my $status = 0;
  for my $sinfo (@{ FindChunk($level, 'term') || [] })
  {
    my $rawtext = MIME::Base64::decode_base64($sinfo->{'text'}[0]{'content'});
    my %pages = ();
    for my $ginfo (@{ $sinfo->{'grouping'} || [] })
    {
      my $group = $ginfo->{'type'};
      if (InGroup($group, qw(unfinished success failure)))
      {
        $status = $group;
        next;
      }
      elsif (InGroup($group, 'end'))
      {
        $status = 0;
        next;
      }
      elsif (!InGroup($group, qw(information checkpoint pict logon logoff)))
      {
        next;
      }
      
#       warn "Processing script $sinfo->{'index'}, group $ginfo->{'index'} ($group)\n";
      
      # collect text and style info
      my @style_runs;
      do {
        my $text_offset = $ginfo->{'start_index'};
        my $text_len = $ginfo->{'length'} - 1;  # null byte at end
        my $text = substr($rawtext, $text_offset, $text_len);
        $text =~ s/\t/ /g;
        
        my @styles = ({ 'change_index' => 0, 'face' => 0, 'color' => 0 });
        for my $cinfo (@{ $sinfo->{'font_change'} || [] })
        {
          my $off = $cinfo->{'change_index'} - $text_offset;
          next if $off < 0;
          last if $off >= $text_len;
          push(@styles, { %$cinfo, 'change_index' => $off });
        }
        
        my $latest_end = $text_len;
        for my $style (reverse @styles)
        {
          my $off = $style->{'change_index'};
          next if $off == $latest_end;
          my $part = substr($text, $off, $latest_end - $off);
          unshift(@style_runs, { %$style, 'text' => $part });
          $latest_end = $off;
        }
      };
      
      # process line breaks
      my @hard_lines;
      do {
        my @current;
        for my $run (@style_runs)
        {
          while ($run->{'text'} =~ s/^(.*?) *\r//s)
          {
            my $part = $1;
            push(@current, { %$run, 'text' => $part });
            push(@hard_lines, [ @current ]);
            @current = ();
          }
          push(@current, $run) if length $run->{'text'};
        }
        push(@hard_lines, [ @current ]) if scalar @current;
        
        @hard_lines = ScrubLines(@hard_lines);
      };
      
      my $filename = $levelnum . '_s' . $sinfo->{'index'};
      $filename .= 'u' if $status == 1;
      $filename .= 's' if $status == 2;
      $filename .= 'f' if $status == 3;
      $filename .= '_p';
      
      my $page_idx = defined($pages{$status}) ? $pages{$status} + 1 : 0;
      $pages{$status} = $page_idx;

      if (InGroup($group, qw(logon logoff)))
      {
        my $cr = StartPage($filename . $page_idx);
        my $r = $rects{'logon_graphic'};
        my $img = LoadImage($ginfo->{'permutation'});
        DrawPicture($cr, $img, $r) if $img;
        my $x = $r->{'x'} + $r->{'w'}/2;
        my $y = $r->{'y'} + $r->{'h'}/2;
        $y += $img->get_height()/2 if $img;
        
        my $width = StyledLineWidth($hard_lines[0]);
        my $message_x = $x - $width/2;
        $message_x = $x - int($width/2) - 4 if $MODE eq 'classic';
        DrawStyledBlock($cr, \@hard_lines, $message_x, $y);
        EndPage($cr, $group, 0);
        next;
      }
      
      # information, checkpoint, pict
      my ($ri, $rt, $img, $err);
      if (InGroup($group, 'information'))
      {
        $rt = $rects{'full_text'};
      }
      else
      {
        if ($ginfo->{'flags'} & $flags{'right'})
        {
          $ri = $rects{'right'};
          $rt = $rects{'left'};
        }
        else
        {
          $ri = $rects{'left'};
          $rt = $rects{'right'};
        }
        
        if (InGroup($group, 'pict'))
        {
          $img = LoadImage($ginfo->{'permutation'});
          $err = "PICT $ginfo->{'permutation'} not found" unless $img;
        }
        elsif (InGroup($group, 'checkpoint'))
        {
          $err = "Goal $ginfo->{'permutation'} not supported";
        }
      }
      
      # line wrapping uses virtual, not actual, width -- monospace only
      my @soft_lines;
      for my $line (@hard_lines)
      {
        push(@soft_lines, WrapLine($rt->{'w'}, $line));
      }
      
      my $lines_per_page = int($rt->{'h'}/$fonts[0]{'height'});
      for my $page (SplitPages($lines_per_page, @soft_lines))
      {
        my $cr = StartPage($filename . $page_idx);
        $page_idx++;
        
        if ($img)
        {
          DrawPicture($cr, $img, $ri);
        }
        elsif ($err)
        {
          $cr->move_to($ri->{'x'} + $ri->{'w'}/2,
                       $ri->{'y'} + $ri->{'h'}/2);
          $cr->set_source_rgb(@{ $text_colors[0] });
          DrawPlainText($cr, $err, $flags{'center'} | $flags{'vcenter'});
        }
        
        DrawStyledBlock($cr, $page, $rt->{'x'}, $rt->{'y'});
        EndPage($cr, $group, 0);
      }
      $pages{$status} = $page_idx - 1;            
    }
  }
}
exit;

sub IndexedHash
{
  my $i = 0;
  return map { $_ => $i++ } @_;
}

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

our $img_filename;
sub StartImage
{
  my ($filename) = @_;
  
  $img_filename = "$OUTDIR/$filename.$FORMAT";
  my $surface;
  if ($FORMAT eq 'png')
  {
    $surface = Cairo::ImageSurface->create('argb32', $WIDTH, $HEIGHT);
  }
  elsif ($FORMAT eq 'pdf')
  {
    $surface = Cairo::PdfSurface->create($img_filename, $WIDTH, $HEIGHT);
  }
  elsif ($FORMAT eq 'svg')
  {
    $surface = Cairo::SvgSurface->create($img_filename, $WIDTH, $HEIGHT);
  }
  my $cr = Cairo::Context->create($surface);
  
  my $scale = $WIDTH/$rects{'screen'}{'w'};
  $cr->scale($scale, $scale) unless $WIDTH == $rects{'screen'}{'w'};
  return $cr;
}

sub EndImage
{
  my ($cr) = @_;
  $cr->show_page();
  if ($FORMAT eq 'png')
  {
    $cr->get_target()->write_to_png($img_filename);
  }
}

sub DummyImage
{
  my $dummy_sub = sub {};
  my $surface;
  if ($FORMAT eq 'png')
  {
    $surface = Cairo::ImageSurface->create('argb32', $WIDTH, $HEIGHT);
  }
  elsif ($FORMAT eq 'pdf')
  {
    $surface = Cairo::PdfSurface->create_for_stream($dummy_sub, undef, $WIDTH, $HEIGHT);
  }
  elsif ($FORMAT eq 'svg')
  {
    $surface = Cairo::SvgSurface->create_for_stream($dummy_sub, undef, $WIDTH, $HEIGHT);
  }
  my $cr = Cairo::Context->create($surface);
  return $cr;
}

sub StartPage
{
  my ($filename) = @_;
  
  my $cr = StartImage($filename);
  $cr->set_antialias('none') if $MODE eq 'classic';
  $cr->rectangle(0, 0, $rects{'screen'}{'w'}, $rects{'screen'}{'h'});
  $cr->set_source_rgb(@{ $colors{'black'} });
  $cr->fill();
  return $cr;
}

sub EndPage
{
  my ($cr, $group, $seconds_elapsed) = @_;
  
  FillRect($cr, $rects{'header'}, $colors{'border_background'});
  FillRect($cr, $rects{'footer'}, $colors{'border_background'});
  $cr->set_source_rgb(@{ $colors{'border_text'} });

  my $text = $strings{'terminal'};
  $text = $strings{'starting_up'} if InGroup($group, 'logon');
  $text = $strings{'disconnecting'} if InGroup($group, 'logoff');
  $cr->move_to($rects{'header'}{'x'} + 3,
               $rects{'header'}{'y'} + $rects{'header'}{'h'}/2);
  DrawPlainText($cr, $text, $flags{'vcenter'});

  $text = FormatDate($seconds_elapsed || 0);
  $cr->move_to($rects{'header'}{'x'} + $rects{'header'}{'w'} - 3,
               $rects{'header'}{'y'} + $rects{'header'}{'h'}/2);
  DrawPlainText($cr, $text, $flags{'vcenter'} | $flags{'right'});

  $text = $strings{'scrolling'};
  $text = $strings{'manufacturer'} if InGroup($group, qw(logon logoff));
  $cr->move_to($rects{'footer'}{'x'} + 3,
               $rects{'footer'}{'y'} + $rects{'footer'}{'h'}/2);
  DrawPlainText($cr, $text, $flags{'vcenter'});

  $text = $strings{'ack'};
  $text = $strings{'address'} if InGroup($group, qw(logon logoff));
  $cr->move_to($rects{'footer'}{'x'} + $rects{'footer'}{'w'} - 3,
               $rects{'footer'}{'y'} + $rects{'footer'}{'h'}/2);
  DrawPlainText($cr, $text, $flags{'vcenter'} | $flags{'right'});

  EndImage($cr);
}

sub DrawPicture
{
  my ($cr, $img, $rect) = @_;

  my $iw = $img->get_width();
  my $ih = $img->get_height();
  
  my $scalex = $rect->{'w'} / $iw;
  my $scaley = $rect->{'h'} / $ih;
  my $scale = $scalex < $scaley ? $scalex : $scaley;
  $scale = 1 if $scale > 1;
    
  my $nw = $scale * $iw;
  my $nh = $scale * $ih;
  my $x = $rect->{'x'} + ($rect->{'w'} - $nw)/2;
  my $y = $rect->{'y'} + ($rect->{'h'} - $nh)/2;
  $x = int($x) if $MODE eq 'classic';
  $y = int($y) if $MODE eq 'classic';
  
  $cr->save();
  $cr->translate($x, $y);
  $cr->scale($scale, $scale);
  $cr->set_source_surface($img, 0, 0);
  $cr->paint();
  $cr->restore();
};

sub FillRect
{
  my ($cr, $rect, $color) = @_;
  
  $cr->rectangle($rect->{'x'}, $rect->{'y'},
                 $rect->{'w'}, $rect->{'h'});
  $cr->set_source_rgb(@$color);
  $cr->fill();
}

sub TextWidth
{
  my ($font, $text) = @_;
  
  my $width = 0;
  for my $char (split(//, $text))
  {
    $width += $font->{'width'}[ord($char)];
  }
  return $width;
}
sub StyledLineWidth
{
  my ($runs) = @_;
  
  my $width = 0;
  for my $run (@$runs)
  {
    $width += TextWidth(StyleFont($run), $run->{'text'});
  }
  return $width;
}
  
sub DrawText
{
  my ($cr, $font, $text, $layout) = @_;
  $layout = 0 unless $layout;
 
  if ($layout & $flags{'center'})
  {
    $cr->rel_move_to(0 - TextWidth($font, $text)/2, 0);
  }
  elsif ($layout & $flags{'right'})
  {
    $cr->rel_move_to(0 - TextWidth($font, $text), 0);
  }
  
  if ($layout & $flags{'vcenter'})
  {
    $cr->rel_move_to(0, 0 - $font->{'height'}/2);
  }
  
  if ($MODE eq 'classic')
  {
    my ($x, $y) = $cr->get_current_point();
    $cr->move_to(int($x), int($y));
  }
  if ($font->{'face'})
  {
    DrawCairoText($cr, $font, $text);
  }
  elsif ($font->{'image'})
  {
    DrawBitmapText($cr, $font, $text);
  }
}

sub DrawCairoText
{
  my ($cr, $font, $text) = @_;
  
  $cr->rel_move_to(0, $font->{'offset'});
  $cr->set_font_face($font->{'face'});
  $cr->set_font_size($font->{'size'});
  $cr->show_text(Encode::decode('MacRoman', $text));
}
sub DrawBitmapText
{
  my ($cr, $font, $text) = @_;
  
  my ($x, $y) = $cr->get_current_point();
  for my $char (split(//, $text))
  {
    my $cnum = ord($char);
    my $img = $font->{'image'}[$cnum];
    if ($img)
    {
      $cr->mask_surface($img, $x + $font->{'xoffset'}, $y);
      $cr->fill();      
    }
    $x += $font->{'width'}[$cnum];
  }
}


sub DrawPlainText
{
  my ($cr, $text, $layout) = @_;
  DrawText($cr, $fonts[0], $text, $layout);
}

sub StyleFont
{
  my ($run) = @_;
  return $fonts[$run->{'face'} & 0x3];
}
sub DrawStyledText
{
  my ($cr, $run) = @_;
  
  $cr->set_source_rgb(@{ $text_colors[$run->{'color'}] });
  my $font = StyleFont($run);
  if ($run->{'face'} & 0x4)
  {
    my ($x, $y) = $cr->get_current_point();
    $cr->rectangle($x, $y + $font->{'offset'} + 1,
                   TextWidth($font, $run->{'text'}), 1);
    $cr->fill();
    $cr->move_to($x, $y);
  }
  DrawText($cr, $font, $run->{'text'});
}

sub DrawStyledLine
{
  my ($cr, $runs, $x, $y) = @_;
  
  my $length = 0;
  for my $run (@$runs)
  {
    $cr->move_to($x + $length, $y);
    DrawStyledText($cr, $run);
    $length += TextWidth(StyleFont($run), $run->{'text'});
  }
}

sub DrawStyledBlock
{
  my ($cr, $lines, $x, $y) = @_;
  
  my $height = 1;
  $height = 2 if $MODE eq 'classic';
  for my $line (@$lines)
  {
    DrawStyledLine($cr, $line, $x, $y + $height);
    $height += $fonts[0]{'height'};
  }
}

sub LineChars
{
  my ($line) = @_;
  
  my $chars = 0;
  map { $chars += length($_->{'text'}) } @$line;
  return $chars;
}

sub FormatDate
{
  my ($seconds_elapsed) = @_;
  
  my @lt = localtime(800070137 + $seconds_elapsed);
  $lt[5] = 437;
  $lt[7] = 0;
  $lt[8] = 0;
  return Time::Format::time_strftime($strings{'date_format'}, @lt);
}

sub InGroup
{
  my ($group, @tags) = @_;
  
  for my $tag (@tags)
  {
    return 1 if $group == $groups{$tag};
  }
  return 0;
}

sub LoadImage
{
  my ($id) = @_;
  
  for my $num ($id + 20000, $id + 10000, $id)
  {
    for my $tmpl ('%s/PICT_%d.png', '%s/%05d.png')
    {
      my $fname = sprintf($tmpl, $IMGDIR, $num);
      if (-f $fname)
      {
        my $img = Cairo::ImageSurface->create_from_png($fname);
        return $img if $img;
      }
    }
  }
  return undef;
}

sub ScrubLines
{
  my (@lines) = @_;
  
  # clean out whitespace at end of lines
  my @new_lines;
  for my $line (@lines)
  {
    my @runs = @$line;
    while (scalar @runs)
    {
      my $last = pop(@runs);
      $last->{'text'} =~ s/ +$//;
      if (length($last->{'text'}))
      {
        push(@runs, $last);
        last;
      }
    }
    push(@new_lines, \@runs);
  }
  
  # clean out empty lines at end
  while (scalar @new_lines)
  {
    my $last = pop(@new_lines);
    if (scalar @$last)
    {
      push(@new_lines, $last);
      last;
    }
  }
  return @new_lines;
}

sub SplitPages
{
  my ($lines_per_page, @lines) = @_;
  
  my @pages;
  while (scalar(@lines) > $lines_per_page)
  {
    push(@pages, [ splice(@lines, 0, $lines_per_page) ]);
  }
  push(@pages, \@lines) if scalar @lines;
  return @pages;
}

sub WrapLine
{
  my ($line_width, $runs) = @_;
  
  return $runs unless scalar @$runs;
  
  my $full_width = StyledLineWidth($runs);
  return $runs if $full_width <= $line_width;
  
  my $width = 0;
  my $chars = 0;
  my $break = 0;
  my $was_space = 0;
  ALL: for my $run (@$runs)
  {
    for my $char (split(//, $run->{'text'}))
    {
      if ($char eq ' ')
      {
        $break = $chars unless $was_space;
        $was_space = 1;
        $width += TextWidth(StyleFont($run), $char);
      }
      else
      {
        $was_space = 0;
        $width += TextWidth(StyleFont($run), $char);
        last ALL if $width > $line_width;
      }
      $chars++;
      $break = $chars if $char eq '-';
    }
  }
  
  my $split = $break || $chars;
  my @queue = @$runs;
  my @new_runs;
  while ($split >= length($queue[0]->{'text'}))
  {
    $split -= length($queue[0]->{'text'});
    push(@new_runs, shift @queue);
  }
  
  my $run = shift @queue;
  my $tleft = substr($run->{'text'}, 0, $split);
  my $tright = substr($run->{'text'}, $split);
  $tright =~ s/^ +//;
  push(@new_runs, { %$run, 'text' => $tleft });
  unshift(@queue, { %$run, 'text' => $tright });
  return (\@new_runs, WrapLine($line_width, \@queue));
}

sub MeasureCairoFont
{
  my ($finfo, $cr) = @_;
  
  $cr->set_font_face($finfo->{'face'});
  $cr->set_font_size($finfo->{'size'});
    
  my $ext = $cr->font_extents();
  $finfo->{'height'} = $ext->{'height'};
  $finfo->{'offset'} = $ext->{'ascent'};
    
  $finfo->{'width'} = [ (0) x 256 ];
  for my $codepoint (32..127, 128..255)
  {
    my $char = chr($codepoint);
    my $text = Encode::decode('MacRoman', $char);
    $finfo->{'width'}[$codepoint] = $cr->text_extents($text)->{'x_advance'};
  }
}

sub LoadTextFont
{
  my ($finfo) = @_;
  
  $finfo->{'width'} = [ (-1) x 256 ];
  $finfo->{'image'} = [];
  my ($imgw, $imgh) = (0, 0);
  
  my $fh;
  open($fh, '<', $finfo->{'textfile'}) or die "Could not open $finfo->{'textfile'}";
  
  while (my $line = <$fh>)
  {
    chomp $line;
    my ($code, @rest) = split(/\s+/, $line);
    my @details;
    for my $i (1..pop(@rest))
    {
      my $dline = <$fh>;
      chomp $dline;
      push(@details, $dline);
    }
    
    if ($code eq 'MT')
    {
      my ($ascent, $descent, $leading, $maxw) = @rest;
      $finfo->{'height'} = $ascent + $descent + $leading;
      $finfo->{'offset'} = $ascent;
    }
    elsif ($code eq 'BB')
    {
      $imgw = $rest[0];
      $imgh = $rest[1];
      $finfo->{'xoffset'} = $rest[2];
    }
    elsif ($code eq 'GM' || $code eq 'GL')
    {
      unshift(@rest, 0) if $code eq 'GM';
      my $codepoint = $rest[0];
      $finfo->{'width'}[$codepoint] = $rest[1];
      next unless scalar @details;
      
      my $surface = Cairo::ImageSurface->create('argb32', $imgw, $imgh);
      my $cr = Cairo::Context->create($surface);
      $cr->set_antialias('none');
      $cr->set_source_rgb(1, 1, 1);
      for my $y (0..(scalar(@details) - 1))
      {
        my @pixels = map { $_ eq '*' } split(//, $details[$y]);
        for my $x (0..(scalar(@pixels) - 1))
        {
          next unless $pixels[$x];
          $cr->rectangle($x, $y, 1, 1);
        }
      }
      $cr->fill();
      $finfo->{'image'}[$codepoint] = $surface;
    }
  }
  
  my $missing_image = $finfo->{'image'}[0];
  my $missing_width = $finfo->{'width'}[0];
  $missing_width = 0 if $missing_width < 0;
  for my $i (0..(scalar(@{ $finfo->{'width'} }) - 1))
  {
    if ($finfo->{'width'}[$i] < 0)
    {
      $finfo->{'width'}[$i] = $missing_width;
      $finfo->{'image'}[$i] = $missing_image;
    }
  }   
}
