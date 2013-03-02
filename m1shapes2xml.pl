#!/usr/bin/perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Writer ();
use MIME::Base64 ();
use Encode ();

my $out = XML::Writer->new('DATA_MODE' => 1, 'DATA_INDENT' => '  ', 'ENCODING' => 'us-ascii');
$out->startTag('shapes');

binmode STDIN;

# Read resource header
my $dataOff = ReadUint32();
my $mapOff = ReadUint32();
my $dataSize = ReadUint32();
my $mapSize = ReadUint32();

my $dataBlob;
if ($dataOff < $mapOff)
{
  ReadPadding($dataOff - CurOffset());
  $dataBlob = ReadRaw($dataSize);
  $dataOff = 0; # it will be, once we switch to reading this blob
}

ReadPadding($mapOff + 24 - CurOffset());
my $typeList = $mapOff + ReadUint16();
ReadPadding($typeList - CurOffset());
my $numTypes = ReadSint16() + 1;

my @typeinfo;
for my $ti (1..$numTypes)
{
  my $typename = ReadRaw(4);
  my $numRefs = ReadUint16() + 1;
  my $refOff = $typeList + ReadUint16();
  push(@typeinfo, [ $refOff, $typename, $numRefs ]);
}

my @datainfo;
for my $tref (sort { $a->[0] <=> $b->[0] } @typeinfo)
{
  my ($off, $name, $numRefs) = @$tref;
  ReadPadding($off - CurOffset());
  
  for my $ni (1..$numRefs)
  {
    my $id = ReadUint16();
    ReadPadding(2);
    my $itemOff = $dataOff + (ReadUint32() & 0xffffff);
    
    push(@datainfo, [ $itemOff, $name, $id ]);
    ReadPadding(4);
  }
}

my @collinfo;
for my $dref (sort { $a->[0] <=> $b->[0] } @datainfo)
{
  my ($off, $name, $id) = @$dref;
  next unless $name eq '.256';
  next unless $id >= 128 && $id <= 159;
  
  my $coll = $id - 128;
  push(@collinfo, [ $off, 0, $coll, 8 ]);
}

SetReadSource($dataBlob) if defined $dataBlob;

for my $cref (sort { $a->[0] <=> $b->[0] } @collinfo)
{
  my ($off, $len, $coll, $depth) = @$cref;
  my $pos = CurOffset();
  next unless $off >= $pos;
  ReadPadding($off - $pos);
  
  $len = ReadUint32();
  
  $out->startTag('collection', 'index' => $coll, 'depth' => $depth);
  my $coll_off = CurOffset();
  # collection header
  {
    my $version = ReadSint16();
    my $coll_type = ReadSint16();
    my $coll_flags = ReadUint16();
    my $color_count = ReadSint16();
    my $cluts = ReadSint16();
    my $coff = ReadSint32();
    my $hcount = ReadSint16();
    my $hoff = ReadSint32();
    my $lcount = ReadSint16();
    my $loff = ReadSint32();
    my $bcount = ReadSint16();
    my $boff = ReadSint32();
    my $coll_pixels_world = ReadSint16();
    my $coll_size = ReadSint32();
    ReadPadding(506);
    $out->emptyTag('definition', 'version' => $version,
          'type' => $coll_type,
#           'color_count' => $color_count, 'clut_count' => $cluts,
#           'color_table_offset' => $coff,
#           'high_level_shape_count' => $hcount,
#           'high_level_shape_offset_table_offset' => $hoff,
#           'low_level_shape_count' => $lcount,
#           'low_level_shape_offset_table_offset' => $loff,
#           'bitmap_count' => $bcount,
#           'bitmap_offset_table_offset' => $boff,
          'pixels_to_world' => $coll_pixels_world,
          );
#     exit;
    
    my @taginfo = (
      [ $coff, 'ctab', $cluts, $color_count ],
      [ $hoff, 'hlsh', $hcount ],
      [ $loff, 'llsh', $lcount ],
      [ $boff, 'bmap', $bcount ]);
    for my $tref (sort { $a->[0] <=> $b->[0] } @taginfo)
    {
      my ($off, $chunk, $count) = @$tref;
      next unless $off > 0;
      next unless $count > 0;
      $off += $coll_off;
      $pos = CurOffset();
      next unless $off >= $pos;
      ReadPadding($off - $pos);
      
      if ($chunk eq 'ctab')
      {
        my $color_count = $tref->[3];
        next unless $color_count > 0;
        for my $clut (0..($count - 1))
        {
          $out->startTag('color_table', 'index' => $clut);
          for my $clr (0..($color_count - 1))
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
      }
      elsif ($chunk eq 'hlsh')
      {
        my @offsets;
        for my $i (0..($count - 1))
        {
          push(@offsets, [ ReadSint32(), $i ]);
        }
        for my $iref (sort { $a->[0] <=> $b->[0] } @offsets)
        {
          my ($ioff, $index) = @$iref;
          next unless $ioff > 0;
          $ioff += $coll_off;
          $pos = CurOffset();
          next unless $ioff >= $pos;
          ReadPadding($ioff - $pos);
  
          my $type = ReadSint16();
          my $flags = ReadUint16();
          my $namesize = ReadUint8();
          my $name = Encode::decode("MacRoman", ReadRaw($namesize));
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
          
          $out->endTag('high_level_shape');
        }
      }
      elsif ($chunk eq 'llsh')
      {
        my @offsets;
        for my $i (0..($count - 1))
        {
          push(@offsets, [ ReadSint32(), $i ]);
        }
        for my $iref (sort { $a->[0] <=> $b->[0] } @offsets)
        {
          my ($ioff, $index) = @$iref;
          next unless $ioff > 0;
          $ioff += $coll_off;
          $pos = CurOffset();
          next unless $ioff >= $pos;
          ReadPadding($ioff - $pos);
  
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
      }
      elsif ($chunk eq 'bmap')
      {
        my @offsets;
        for my $i (0..($count - 1))
        {
          push(@offsets, [ ReadSint32(), $i ]);
        }
        for my $iref (sort { $a->[0] <=> $b->[0] } @offsets)
        {
          my ($ioff, $index) = @$iref;
          next unless $ioff > 0;
          $ioff += $coll_off;
          $pos = CurOffset();
          next unless $ioff >= $pos;
          ReadPadding($ioff - $pos);
  
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
            my $nul = chr(0);
            my $rowct = $column ? $width : $height;
            my $rowlen = $column ? $height : $width;
            
            for my $col (1..$rowct)
            {
              # read M1-format line
              my $linedata = '';
              while (1)
              {
                my $opcode = ReadSint16();
                if ($opcode > 0)
                {
                  $linedata .= ReadRaw($opcode);
                }
                elsif ($opcode < 0)
                {
                  $linedata .= $nul x -$opcode;
                }
                else
                {
                  last;
                }
              }
              
              
              # translate to M2-format

              if (length($linedata) != $rowlen)
              {
                print STDERR "Wrong line length: " . length($linedata) . " instead of " . $rowlen . "\n";
              }
              
              $linedata =~ s/$nul+$//;
              my $endlen = length($linedata);
              $linedata =~ s/^$nul+//;
              my $beglen = length($linedata);
              
              my $last_row = $endlen;
              my $first_row = $endlen - $beglen;
              $bdata .= pack('s>s>', $first_row, $last_row);
              $bdata .= $linedata;
            }
          }
          $out->characters(MIME::Base64::encode_base64($bdata));
          $out->endTag('bitmap');
        }
      }
    }
  }
  $out->endTag('collection');
}

$out->endTag('shapes');
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

our $BLOB = undef;
our $BLOBoff = 0;
our $BLOBlen = 0;
sub SetReadSource
{
  my ($data) = @_;
  $BLOB = $_[0];
  $BLOBoff = 0;
  $BLOBlen = defined($BLOB) ? length($BLOB) : 0;
}
sub SetReadOffset
{
  my ($off) = @_;
  die "Can't set offset for piped data" unless defined $BLOB;
  die "Bad offset for data" if (($off < 0) || ($off > $BLOBlen));
  $BLOBoff = $off;
}
sub CurOffset
{
  return $BLOBoff;
}
sub ReadRaw
{
  my ($size, $nofail) = @_;
  die "Can't read negative size" if $size < 0;
  return '' if $size == 0;
  if (defined $BLOB)
  {
    my $left = $BLOBlen - $BLOBoff;
    if ($size > $left)
    {
      return undef if $nofail;
      die "Not enough data in blob (offset $BLOBoff, length $BLOBlen)";
    }
    $BLOBoff += $size;
    return substr($BLOB, $BLOBoff - $size, $size);
  }
  else
  {
    my $chunk;
    my $rsize = read STDIN, $chunk, $size;
    $BLOBoff += $rsize;
    unless ($rsize == $size)
    {
      return undef if $nofail;
      die "Failed to read $size bytes";
    }
    return $chunk;
  }
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

