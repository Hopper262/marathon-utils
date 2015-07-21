#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use Image::Magick ();
use XML::Simple ();
use MIME::Base64 ();

my $basedir = $ARGV[0] || 'images';
mkdir $basedir;

my $fmt = $ARGV[1] || '';

my $usage = "Usage: $0 [image-dir [format]] < <shapes.xml>\n";
my $xml = XML::Simple::XMLin('-', 'KeyAttr' => [], 'ForceArray' => 1);
die $usage unless $xml;
our $colls = $xml->{'collection'};
die $usage unless $colls;

for my $coll (@$colls)
{
  my $id = $coll->{'index'};
  my $colldir = "$basedir/$id";
  
  for my $ct (@{ $coll->{'color_table'} })
  {
    my $tab = $ct->{'index'};
    my $tabdir = "$colldir/$tab";
    
    my @clrs;
    for my $color (@{ $ct->{'color'} })
    {
      my $ci = $color->{'value'};
      $clrs[$ci] = [ ($color->{'red'} || 0) / 65535,
                     ($color->{'green'} || 0) / 65535,
                     ($color->{'blue'} || 0) / 65535,
                     ($ci < 3 ? 1.0 : 0.0) ];
    }
    
    my @images;
    for my $bm (@{ $coll->{'bitmap'} })
    {
      my $bi = $bm->{'index'};
      my $fname = sprintf("$tabdir/bitmap%03d.$fmt", $bi);
      
      my $width = $bm->{'width'};
      my $height = $bm->{'height'};
      next unless $width && $height;
      my $img = $images[$bi] = Image::Magick->new();
      $img->Set('size' => $width . 'x' . $height);
      $img->Read('canvas:rgb(0,0,255,0)');
      $img->Set('matte' => 'True');
      $img->Set('alpha' => 'On');
      
      my $column = $bm->{'column_order'};
      my $rowct = $column ? $width : $height;
      my $rowlen = $column ? $height : $width;
      my $xs = $column ? 'y' : 'x';
      my $ys = $column ? 'x' : 'y';

      my $rpixels = MIME::Base64::decode_base64($bm->{'content'});
      my $pixels = $rpixels;
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
      
      my $offset = 0;
      for my $col (0..($rowct - 1))
      {
        for my $row (0..($rowlen - 1))
        {
          my $pi = unpack('C', substr($pixels, $offset++, 1));          
          my $err = $img->SetPixel($ys => $col, $xs => $row,
                                   'channel' => 'All',
                                   'color' => $clrs[$pi]);
          die $err if $err;
        }
      }
      
      if ($fmt)
      {
        mkdir $colldir;
        mkdir $tabdir;
        my $err = $img->Write($fname);
        die $err if $err;
      }
    }
    
    my @frame_images;
    my @frame_metas;
    for my $fr (@{ $coll->{'low_level_shape'} })
    {
      my $fi = $fr->{'index'};
      $frame_metas[$fi] = $fr;
      my $xmirror = $fr->{'x_mirror'};
      my $ymirror = $fr->{'y_mirror'};
      my $subf = $fr->{'window_frame'};
      
      my $bimg = $images[$fr->{'bitmap_index'}];
      next unless $bimg;
      my $img = $frame_images[$fi] = $bimg->Clone();
      
      if ($subf)
      {
        my $simg = $images[$subf];
        next unless $simg;
        $img->Composite('image' => $simg, 'compose' => 'Over',
            'x' => $fr->{'window_left'}, 'y' => $fr->{'window_top'});
      }
      if ($xmirror)
      {
        $img->Flop();
      }
      if ($ymirror)
      {
        $img->Flip();
      }
      
      my $fname = sprintf("$tabdir/frame%03d.$fmt", $fi);
      if ($fmt)
      {
        mkdir $colldir;
        mkdir $tabdir;
        my $err = $img->Write($fname);
        die $err if $err;
      }
    }
    
    SEQ:
    for my $seq (@{ $coll->{'high_level_shape'} })
    {
      my $si = $seq->{'index'};
      my $fpv = $seq->{'frames_per_view'};
      next if $fpv < 1;
#       next if $fpv < 2;
      
      my $views = $seq->{'number_of_views'};
#       next if $views == 10;
      
      my $ticks = $seq->{'ticks_per_frame'};
      $ticks = 1 if $ticks < 1;
#       next if $ticks < 1;
      my $delay = ($ticks * 100 / 30);
      
      my $actual_views = $views;
      $actual_views = 1 if ($views == 10);
      $actual_views = 4 if ($views == 3);
      $actual_views = 5 if ($views == 9 || $views == 11);
      $actual_views = 8 if ($views == 5);
      
      if ($views == 10)
      {
        # treat random-frame like multiple views
        $actual_views = $fpv;
        $fpv = 1;
      }
      next if $actual_views < 1;
      
      my $off = 0;
      for my $viewnum (0..($actual_views - 1))
      {
        my @frame_indices;
        for my $fref (0..($fpv - 1))
        {
          push(@frame_indices, $seq->{'frame'}[$off++]{'index'});
        }
        next SEQ unless scalar @frame_indices;
        
        my ($top, $left, $bottom, $right) = (1000, 1000, -1000, -1000);
        for my $idx (@frame_indices)
        {
          next SEQ if $idx < 0;
          next SEQ unless $frame_images[$idx];
          
          my $bw = $frame_images[$idx]->Get('width');
          my $bh = $frame_images[$idx]->Get('height');
          my $ox = $frame_metas[$idx]->{'origin_x'};
          my $oy = $frame_metas[$idx]->{'origin_y'};
          
          my $frame_left = -$ox;
          my $frame_top = -$oy;
          my $frame_right = $bw - $ox;
          my $frame_bottom = $bh - $oy;
          
          $left = $frame_left if $frame_left < $left;
          $top = $frame_top if $frame_top < $top;
          $right = $frame_right if $frame_right > $right;
          $bottom = $frame_bottom if $frame_bottom > $bottom;
        }
        
        my $seq_img = Image::Magick->new('size' => ($right - $left) . 'x' . ($bottom - $top));
        for my $idx (@frame_indices)
        {
          my $bw = $frame_images[$idx]->Get('width');
          my $bh = $frame_images[$idx]->Get('height');
          my $ox = $frame_metas[$idx]->{'origin_x'};
          my $oy = $frame_metas[$idx]->{'origin_y'};
          
          my $frame_left = -$ox;
          my $frame_top = -$oy;
          my $frame_right = $bw - $ox;
          my $frame_bottom = $bh - $oy;

          my $geo = $bw . 'x' . $bh .
                    '+' . ($frame_left - $left) .
                    '+' . ($frame_top - $top);
          
          my $img = $frame_images[$idx]->Clone();
          if ($fpv > 1)
          {
            my $fimg = Image::Magick->new('size' => ($right - $left) . 'x' . ($bottom - $top));
            $fimg->Read('canvas:rgb(0,0,255,0)');
            $fimg->Set('alpha' => 'On');
            $fimg->Composite('image' => $img,
                             'x' => $frame_left - $left,
                             'y' => $frame_top - $top,
                             'compose' => 'Src',
                             );
            $fimg->Set('dispose' => 'Previous',
                       'loop' => 0,
                       'delay' => $delay,
                       );
            push(@$seq_img, $fimg);
          }
          else
          {
            $seq_img = $img;
          }
        }
        
        my $name = $seq->{'name'} || '';
        $name =~ s/(\W|_)+/_/g;
        $name =~ s/^_//;
        $name =~ s/_$//;
        $name = "-$name" if length $name;
        
        my $sfmt = ($fpv > 1) ? 'gif' : $fmt;
        my $fname = sprintf("$tabdir/seq%03d$name-%d.$sfmt", $si, $viewnum);
        if ($sfmt)
        {
          mkdir $colldir;
          mkdir $tabdir;
          my $err = $seq_img->Write($fname);
          die $err if $err;
        }
      }
    }
  }
}

exit;
