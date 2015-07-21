#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Writer ();
use URI::Escape ();

my $out = XML::Writer->new('DATA_MODE' => 1, 'DATA_INDENT' => '  ', 'ENCODING' => 'us-ascii');
$out->startTag('shapes_patch');

binmode STDIN;
my $chunk;
while ($chunk = ReadRaw(8, 1))
{
  my ($coll_idx, $bit_depth) = unpack('L>[2]', $chunk);
  $out->startTag('collection', 'index' => $coll_idx, 'depth' => $bit_depth);
  
  my $color_count = 0;
  while ($chunk = ReadRaw(4))
  {
    if ($chunk eq 'cldf')
    {
      my $version = ReadSint16();
      my $type = ReadSint16();
      my $flags = ReadUint16();
      $color_count = ReadSint16();
      my $cluts = ReadSint16();
      my $coff = ReadSint32();
      my $hcount = ReadSint16();
      my $hoff = ReadSint32();
      my $lcount = ReadSint16();
      my $loff = ReadSint32();
      my $bcount = ReadSint16();
      my $boff = ReadSint32();
      my $pixels_world = ReadSint16();
      my $size = ReadSint32();
      ReadPadding(506);
      
      $out->emptyTag('definition', 'version' => $version,
            'type' => $type,
            'color_count' => $color_count, 'clut_count' => $cluts,
#             'color_table_offset' => $coff,
            'high_level_shape_count' => $hcount,
#             'high_level_shape_offset_table_offset' => $hoff,
            'low_level_shape_count' => $lcount,
#             'low_level_shape_offset_table_offset' => $loff,
            'bitmap_count' => $bcount,
#             'bitmap_offset_table_offset' => $boff,
            'pixels_to_world' => $pixels_world,
            );
    }
    elsif ($chunk eq 'ctab')
    {
      my $index = ReadSint32();
      $out->startTag('color_table', 'index' => $index);
      for my $i (1..$color_count)
      {
        my $flags = ReadUint8();
        my $val = ReadUint8();
        my $red = ReadUint16();
        my $green = ReadUint16();
        my $blue = ReadUint16();
        my $lum = ($flags & 0x80) ? 1 : 0;
        $out->emptyTag('color', 'self_luminescent' => $lum, 'value' => $val, 'red' => $red, 'green' => $green, 'blue' => $blue);
      }
      $out->endTag('color_table');
    }
    elsif ($chunk eq 'hlsh')
    {
      my $index = ReadSint32();
      my $size = ReadSint32();

      my $type = ReadSint16();
      my $flags = ReadUint16();
      my $namesize = ReadUint8();
      my $name = ReadRaw($namesize);
      ReadPadding(33 - $namesize);
      my $views = ReadSint16();
      my $frames_per_view = ReadSint16();
      my $ticks_per_frame = ReadSint16();
      my $key = ReadSint16();
      my $xfer_mode = ReadSint16();
      my $xfer_period = ReadSint16();
      my $first_snd = ReadSint16();
      my $key_snd = ReadSint16();
      my $last_snd = ReadSint16();
      my $pixels_world = ReadSint16();
      my $loop = ReadSint16();
      ReadPadding(28);
      
      $out->startTag('high_level_shape', 'index' => $index,
            'type' => $type,
            'name' => $name, 'number_of_views' => $views,
            'frames_per_view' => $frames_per_view,
            'ticks_per_frame' => $ticks_per_frame,
            'key_frame' => $key,
            'transfer_mode' => $xfer_mode,
            'transfer_mode_period' => $xfer_period,
            'first_frame_sound' => $first_snd,
            'key_frame_sound' => $key_snd,
            'last_frame_sound' => $last_snd,
            'pixels_to_world' => $pixels_world,
            'loop_frame' => $loop,
            );
      
      if (($views > 0) && ($frames_per_view > 0))
      {
        my $actual_views = $views;
        $actual_views = 1 if ($views == 10);
        $actual_views = 4 if ($views == 3);
        $actual_views = 5 if ($views == 9 || $views == 11);
        $actual_views = 8 if ($views == 5);
        
        my $framect = $actual_views * $frames_per_view;
        for my $i (1..$framect)
        {
          $out->emptyTag('frame', 'index' => ReadSint16());
        }
      }
      ReadSint16();  # terminator

      $out->endTag('high_level_shape');
    }
    elsif ($chunk eq 'llsh')
    {
      my $index = ReadSint32();
      
      my $flags = ReadUint16();
      my $xmirror = ($flags & 0x8000) ? 1 : 0;
      my $ymirror = ($flags & 0x4000) ? 1 : 0;
      my $obscure = ($flags & 0x2000) ? 1 : 0;
      
      my $min_intensity = ReadFixed();
      my $bitmap = ReadSint16();
      my $origx = ReadSint16();
      my $origy = ReadSint16();
      my $keyx = ReadSint16();
      my $keyy = ReadSint16();
      my $wl = ReadSint16();
      my $wr = ReadSint16();
      my $wt = ReadSint16();
      my $wb = ReadSint16();
      my $wx = ReadSint16();
      my $wy = ReadSint16();
      ReadPadding(8);
      
      $out->emptyTag('low_level_shape', 'index' => $index,
            'x_mirror' => $xmirror, 'y_mirror' => $ymirror,
            'keypoint_obscured' => $obscure,
            'minimum_light_intensity' => $min_intensity,
            'bitmap_index' => $bitmap,
            'origin_x' => $origx, 'origin_y' => $origy,
            'key_x' => $keyx, 'key_y' => $keyy,
            'world_left' => $wl, 'world_right' => $wr,
            'world_top' => $wt, 'world_bottom' => $wb,
            'world_x0' => $wx, 'world_y0' => $wy,
            );
    }
    elsif ($chunk eq 'bmap')
    {
      my $index = ReadSint32();
      my $size = ReadSint32();

      my $width = ReadSint16();      
      my $height = ReadSint16();      
      my $bytes_row = ReadSint16();      
      my $flags = ReadUint16();      
      my $column = ($flags & 0x8000) ? 1 : 0;
      my $transp = ($flags & 0x4000) ? 1 : 0;
      my $depth = ReadSint16();      
      
      ReadPadding(16);
      my $addrs = 4 * ($column ? $width + 1 : $height + 1);
      ReadPadding($addrs);
      
      $out->startTag('bitmap', 'index' => $index,
            'width' => $width, 'height' => $height,
            'bytes_per_row' => $bytes_row,
            'column_order' => $column,
            'transparent' => $transp,
            'bit_depth' => $depth,
            );
            
      # get bitmap data, decoding if necessary
      my $bdata;
      if ($bytes_row > -1)
      {
        $bdata = ReadRaw($width * $height);
      }
      else
      {
        for my $col (1..$width)
        {
          my $first_row = ReadSint16();
          my $last_row = ReadSint16();
          $bdata .= pack('s>s>', $first_row, $last_row);
          $bdata .= ReadRaw($last_row - $first_row);
        }
      }
      $out->characters(unpack('H*', $bdata));
      $out->endTag('bitmap');
      
    }
    elsif ($chunk eq 'endc')
    {
      last;
    }
  }
  $out->endTag('collection');
}

$out->endTag('shapes_patch');
$out->end();
exit;

sub ReadUint32
{
  return ReadPacked('L>', 4);
}
sub ReadSint32
{
  return ReadPacked('l>', 4);
}
sub ReadUint16
{
  return ReadPacked('S>', 2);
}
sub ReadSint16
{
  return ReadPacked('s>', 2);
}
sub ReadUint8
{
  return ReadPacked('C', 1);
}
sub ReadFixed
{
  my $fixed = ReadSint32();
  return $fixed / 65536.0;
}

sub ReadRaw
{
  my ($size, $nofail) = @_;
  my $chunk;
  if ($size < 0)
  {
    die "Can't read $size bytes" unless $nofail;
    return undef;
  }
  return '' if ($size == 0);
  unless (read STDIN, $chunk, $size)
  {
    return undef if $nofail;
    die "Failed to read $size bytes";
  }
  return $chunk;
}
sub ReadPadding
{
  ReadRaw(@_);
}
sub ReadPacked
{
  my ($template, $size) = @_;
  return unpack($template, ReadRaw($size));
}

