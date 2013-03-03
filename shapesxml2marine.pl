#!/usr/bin/perl
use strict;
use warnings 'FATAL' => 'all';
use List::Util qw(min max);
use MIME::Base64 ();
use Image::Magick ();
use XML::Simple ();

our $out_dir = $ARGV[0] || '.';
mkdir $out_dir unless (-d $out_dir);

our $SHAPES = XML::Simple::XMLin('-', 'KeyAttr' => [], 'ForceArray' => 1);
our $mar = IndexOf($SHAPES->{'collection'}, 6);

our @COLORNAMES = qw(slate red violet yellow white orange blue green);
our @SEQNAMES = qw(
  running fist-idle fist-firing pistol-idle pistol-firing
  pistol2-idle pistol2-firing stationary dying-soft dying-hard
  dead-soft dead-hard flame-idle flame-firing rocket-idle
  rocket-firing shotgun-idle shotgun-firing shotgun2-idle shotgun2-firing
  fusion-idle fusion-charged fusion-firing airborne sliding
  walking ar-idle ar-firing ball dummy-ball
  dummy-hand alien-idle alien-firing smg-idle smg-firing
  );

our @DYING = (8, 9);
our @DEAD = (10, 11);
our @LEGS = (0, 7, 23, 24, 25);
our @TORSOS = (1, 2,
               3, 4, 5, 6,
               12, 13, 14, 15,
               16, 17, 18, 19,
               20, 21, 22,
               26, 27, 28,
               31, 32, 33, 34);

my @bitmap_meta = ();
for my $i (0..MaxOf($mar->{'bitmap'}))
{
  my $bmap = IndexOf($mar->{'bitmap'}, $i);
  my ($px, $mpx) = UnpackBitmap($bmap);
  $bitmap_meta[$i] = { 'width' => 0 + $bmap->{'width'},
                       'height' => 0 + $bmap->{'height'},
                       'data' => $px,
                       'data_xmirror' => $mpx,
                      };
}

my @frame_meta = ();
for my $i (0..MaxOf($mar->{'low_level_shape'}))
{
  my $llsh = IndexOf($mar->{'low_level_shape'}, $i);
  my $bmap = $bitmap_meta[$llsh->{'bitmap_index'}];
  $frame_meta[$i] = {
    'width' => $bmap->{'width'},
    'height' => $bmap->{'height'},
    'l' => $llsh->{'origin_x'},
    'r' => $bmap->{'width'} - $llsh->{'origin_x'},
    't' => $llsh->{'origin_y'},
    'b' => $bmap->{'height'} - $llsh->{'origin_y'},
    'x' => $llsh->{'key_x'} - $llsh->{'origin_x'},
    'y' => $llsh->{'key_y'} - $llsh->{'origin_y'},
    'data' => $llsh->{'x_mirror'} ? $bmap->{'data_xmirror'}
                                  : $bmap->{'data'},
    };
}

my @color_tables = ();
for my $i (0..7)
{
  my $ctab = IndexOf($mar->{'color_table'}, $i);
  my @colors = ();
  for my $clr (@{ $ctab->{'color'} })
  {
    my $val = $clr->{'value'};
    next if $val < 3;
    $colors[$val] = [ ($clr->{'red'} || 0) / 65535,
                      ($clr->{'green'} || 0) / 65535,
                      ($clr->{'blue'} || 0) / 65535,
                      1.0 ];
  }
  $color_tables[$i] = \@colors;
}

for my $cidx (0..7)
{
  my $clrdir = $out_dir . '/' . $COLORNAMES[$cidx];
  mkdir $clrdir;
  my $ctab = $color_tables[$cidx];
  
  for my $sidx (@DEAD)
  {
    my $fdir = "$clrdir/" . $SEQNAMES[$sidx];
    mkdir $fdir;
    
    my $seq = IndexOf($mar->{'high_level_shape'}, $sidx);
    my $opt = 0;
    for my $fr (@{ $seq->{'frame'} })
    {
      my $fm = $frame_meta[$fr->{'index'}];
      my $img = DrawFrame(FreshImage(), $fm, $ctab, 0, 0);
      SaveImage($img, "$fdir/option$opt");
      $opt++;
    }
  }

  for my $sidx (@DYING)
  {
    my $fdir = "$clrdir/" . $SEQNAMES[$sidx];
    mkdir $fdir;
    
    my $seq = IndexOf($mar->{'high_level_shape'}, $sidx);
    
    my $fidx = 0;
    for my $view (0, 2, 4, 6)
    {
      for my $step (0..($seq->{'frames_per_view'} - 1))
      {
        my $fr = $seq->{'frame'}[$fidx++];
        my $fm = $frame_meta[$fr->{'index'}];
        my $img = DrawFrame(FreshImage(), $fm, $ctab, 0, 0);
        SaveImage($img, "$fdir/view$view anim$step");
      }
    }
  }
  
  for my $tsidx (@TORSOS)
  {
    my $tseq = IndexOf($mar->{'high_level_shape'}, $tsidx);
    my $tsteps = $tseq->{'frames_per_view'};
    my $tdir = "$clrdir/" . $SEQNAMES[$tsidx];
    mkdir $tdir;
    for my $lsidx (@LEGS)
    {
      my $lseq = IndexOf($mar->{'high_level_shape'}, $lsidx);
      my $lsteps = $lseq->{'frames_per_view'};
      my $fdir = "$tdir/" . $SEQNAMES[$lsidx];
      mkdir $fdir;
      
      for my $view (0..7)
      {
        for my $tstep (0..($tsteps - 1))
        {
          my $tfr = $tseq->{'frame'}[($view * $tsteps) + $tstep];
          my $tfm = $frame_meta[$tfr->{'index'}];
          
          for my $lstep (0..($lsteps - 1))
          {
            my $lfr = $lseq->{'frame'}[($view * $lsteps) + $lstep];
            my $lfm = $frame_meta[$lfr->{'index'}];
            
            my $img = DrawFrame(FreshImage(), $lfm, $ctab, 0, 0);
            DrawFrame($img, $tfm, $ctab, $lfm->{'x'}, $lfm->{'y'});
            SaveImage($img, "$fdir/view$view anim$tstep-$lstep");
          }
        }
      }
    }
  }
  
}  

exit;


sub IndexOf
{
  my ($ref, $idx) = @_;
  
  for my $r (@$ref)
  {
    if ($r->{'index'} == $idx)
    {
      return $r;
    }
  }
  return undef;
}

sub MaxOf
{
  my ($ref) = @_;
  return -1 unless $ref;
  return scalar(@$ref) - 1;
}

sub UnpackBitmap
{
  my ($bm) = @_;
  
  my $rpixels = MIME::Base64::decode_base64($bm->{'content'});
  my $pixels = $rpixels;
  my $rowct = $bm->{'column_order'} ? $bm->{'width'} : $bm->{'height'};
  my $rowlen = $bm->{'column_order'} ? $bm->{'height'} : $bm->{'width'};
  if ($bm->{'bytes_per_row'} < 0)
  {
    # unpack pixel data
    my $offset = 0;
    $pixels = '';
    for my $col (0..($rowct - 1))
    {
      my $first_row = unpack('n', substr($rpixels, $offset, 2));
      $offset += 2;
      if ($first_row > 0)
      {
        $pixels .= chr(0) x $first_row;
      }
      my $last_row = unpack('n', substr($rpixels, $offset, 2));
      $offset += 2;
      
      if ($last_row > $first_row)
      {
        my $rsize = $last_row - $first_row;
        $pixels .= substr($rpixels, $offset, $rsize);
        $offset += $rsize;
      }
      if ($last_row < $rowlen)
      {
        $pixels .= chr(0) x ($rowlen - $last_row);
      }
    }
  }
  
  if ($bm->{'column_order'})
  {
    $pixels = FlipPixels($pixels, $rowct, $rowlen);
  }
  my $mpixels = XMirrorPixels($pixels, $bm->{'width'}, $bm->{'height'});
  
  return ($pixels, $mpixels);
}

sub FlipPixels
{
  my ($orig, $width, $height) = @_;
  
  my $new = '';
  for my $y (0..($height - 1))
  {
    for my $x (0..($width - 1))
    {
      $new .= substr($orig, ($x * $height) + $y, 1);
    }
  }
  return $new;
}
  
sub XMirrorPixels
{
  my ($orig, $width, $height) = @_;
  
  my $new = '';
  for my $y (0..($height - 1))
  {
    my $origrow = substr($orig, $y * $width, $width);
    $new .= reverse($origrow);
  }
  return $new;
}
  
sub FreshImage
{
  my $img = Image::Magick->new();
  $img->Set('size' => '200x200');
  $img->Read('canvas:rgb(0,0,255,1)');
  $img->Set('alpha' => 'Off');
  return $img;
}

sub DrawFrame
{
  my ($img, $frame, $ctab, $x, $y) = @_;
  $x += 100 - $frame->{'l'};
  $y += 170 - $frame->{'t'};
  
  my $offset = 0;
  for my $row (0..($frame->{'height'} - 1))
  {
    for my $col (0..($frame->{'width'} - 1))
    {
      my $pi = unpack('C', substr($frame->{'data'}, $offset++, 1));
      my $clr = $ctab->[$pi];
      next unless $clr;
      my $err = $img->SetPixel('x' => $x + $col,
                               'y' => $y + $row,
                               'channel' => 'All',
                               'color' => $clr);
      die $err if $err;
    }
  }
  return $img;
}

sub SaveImage
{
  my ($img, $path) = @_;
  
  my $err = $img->Write("$path.gif");
  die $err if $err;
}
