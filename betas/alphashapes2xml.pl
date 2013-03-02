#!/usr/bin/perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Writer ();
use Encode ();
use MIME::Base64 ();
use Carp ();

$SIG{__DIE__} = \&Carp::croak;

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

my (@datainfo, %residsused);
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
    $residsused{$id} = 1;
    ReadPadding(4);
  }
}

my (@collinfo, %sgrpinfo);
for my $dref (sort { $a->[0] <=> $b->[0] } @datainfo)
{
  my ($off, $name, $id) = @$dref;
  next unless ($name eq '.256' || $name eq 'sgrp');
  
  my $coll = $id - 128;
  my $colltype = 2;
  if ($coll < 64  || $coll == 68) { $colltype = 1; }
  if ($coll == 64 || $coll == 67) { $colltype = 3; }
    
  SetReadSource($dataBlob) if defined $dataBlob;
  ReadPadding($off);
  my $origlen = ReadUint32();
  
  if ($name eq '.256')
  {
    my $data = UnpackResource();
    push(@collinfo, [ 0, length($data), $coll, 8, $data, $colltype ]);
  }
  elsif ($name eq 'sgrp')
  {
    my $ct = ReadUint16();
    my $data = ReadPadding($origlen - 2);
    $sgrpinfo{$coll} = [ $ct, $data ];
  }
}

# SetReadSource($dataBlob) if defined $dataBlob;

my $outcoll = 0;
for my $cref (sort { $a->[0] <=> $b->[0] } @collinfo)
{
  my ($off, $len, $coll, $depth, $data, $colltype) = @$cref;
  SetReadSource($data);
  
  $out->startTag('collection', 'index' => $outcoll++, 'depth' => $depth);
  $out->emptyTag('definition', 'version' => 3, 'type' => $colltype);
  
  my $coll_off = CurOffset();
  # collection header
  my $lcount = ReadUint32();
  my $loff = ReadSint32();
  my $boff = ReadSint32();
  
  my ($hcount, $hdata) = (0, undef);
  if ($sgrpinfo{$coll})
  {
    ($hcount, $hdata) = @{ $sgrpinfo{$coll} };
  }
  
  my $lcount2 = ($boff - $loff) / ($hdata ? 32 : 8);
  warn "Low count mismatch: $lcount2 vs. $lcount\n" if ($lcount != $lcount2);
  
  my $color_count = ReadSint16();
  my $clut_count = ReadSint16();
  
  # color tables (FYI, multiple cluts were not used in demo)
  for my $clut (0..($clut_count - 1))
  {
    $out->startTag('color_table', 'index' => $clut);
  
    # transparent colors
    $out->emptyTag('color', 'value' => 0, 'red' => 0, 'green' => 0, 'blue' => 65535);
    $out->emptyTag('color', 'value' => 1, 'red' => 65535, 'green' => 0, 'blue' => 65535);
    $out->emptyTag('color', 'value' => 2, 'red' => 0, 'green' => 65535, 'blue' => 65535);
    for my $clr (1..$color_count)
    {
      my $val = ReadUint16();
      warn "Color index mismatch: $val vs. $clr\n" if ($val != $clr + 2);
      my $red = ReadUint16();
      my $green = ReadUint16();
      my $blue = ReadUint16();

      $out->emptyTag('color', 'value' => $val, 'red' => $red, 'green' => $green, 'blue' => $blue);
    }
    $out->endTag('color_table');
  }
  
  ## high level shapes (sequences)
  ## these are stored separately, in sgrp resources
  if ($hdata)
  {
    my $oldpos = CurOffset();
    
    SetReadSource($hdata);
    for my $i (0..($hcount - 1))
    {
      my $type = ReadSint16();

      my $first_fwd_frame = ReadSint16();
      my $frames_per_view = ReadSint16();
      my $key_frame = ReadSint16();
      my $ticks_per_frame = ReadSint16();
      my $first_snd = ReadSint16();
      my $last_snd = ReadSint16();
      
      my $val = ReadSint16();
      warn "Unknown value not -1 in coll $coll, sgrp $i ($val)\n" if ($val != -1);
      for my $dummy (1..8)
      {
        $val = ReadSint16();
        warn "Non-zero item in coll $coll, sgrp $i\n" if ($val != 0);
      }
      
      next if ($type == 0);
      
      my %view_lookup = (
        1 => [ 1, [ 0 ]],
        3 => [ 9, [ 0, -1, -2, 2, 1 ]],
        4 => [ 5, [ 0, -1, -2, -3, -4, 3, 2, 1 ]],
        );
      
      my $v = $view_lookup{$type};
      unless ($v)
      {
        warn "Unknown view type $type in coll $coll, sgrp $i\n";
        next;
      }
      
      $out->startTag('high_level_shape', 'index' => $i,
          'number_of_views' => $v->[0],
          'frames_per_view' => $frames_per_view,
          'ticks_per_frame' => $ticks_per_frame,
          'key_frame' => $key_frame,
          'transfer_mode' => 0,
          'transfer_mode_period' => $frames_per_view * $ticks_per_frame,
          'first_frame_sound' => $first_snd,
          'key_frame_sound' => -1,
          'last_frame_sound' => $last_snd,
          );

      for my $voff (@{ $v->[1] })
      {
        my $start = $first_fwd_frame + ($voff * $frames_per_view);
        for my $step (0..($frames_per_view - 1))
        {
          $out->emptyTag('frame', 'index' => $start + $step);
        }
      }
      
      $out->endTag('high_level_shape');
    }
    
    SetReadSource($data);
    ReadPadding($oldpos);
  }
  

  
  my $newpos = CurOffset();
  if ($newpos != $loff)
  {
    warn "Low offset mismatch: $loff vs. $newpos\n";
    ReadPadding($loff - $newpos);
  }
  
  # low level shapes, first pass
  # we'll output after we read bitmap sizes
  my (@lshs, %bmaps);
  for my $i (0..($lcount - 1))
  {
    my $boff2 = $boff + ReadSint32();
    $bmaps{$boff2} = [] unless $bmaps{$boff2};
    push(@{ $bmaps{$boff2} }, $i);
    
    unless ($hdata)
    {
      my $val = ReadSint16();
      warn "Non-zero item in coll $coll, llsh $i (offset " . CurOffset() . ")\n" if ($val != 0);
    }
    
    my $flags = ReadUint16();
    my $xmirror = ($flags & 0x8000) ? 1 : 0;
    my $ymirror = ($flags & 0x4000) ? 1 : 0;
    my $obscure = ($flags & 0x2000) ? 1 : 0;
    unless ($hdata)
    {
      $xmirror = 0;  # actually a transparency flag...
    }

    my ($wl, $wr, $wt, $wb, $wx, $wy) = (0, 0, 0, 0, 0, 0);
    if ($hdata)
    {
      $wl = ReadSint16();
      $wt = ReadSint16();
      $wr = ReadSint16();
      $wb = ReadSint16();
      $wx = ReadSint16();
      $wy = ReadSint16();
    
      for my $dummy (1..7)
      {
        my $val = ReadSint16();
        warn "Non-zero item in coll $coll, llsh $i (offset " . CurOffset() . ")\n" if ($val != 0);
      }
    }
    
    push(@lshs, [ $boff2, 0, 0, $xmirror, $ymirror, $obscure, $wl, $wr, $wt, $wb, $wx, $wy ]);
  }
  
  $newpos = CurOffset();
  if ($newpos != $boff)
  {
    warn "Coll $coll: Bitmap offset mismatch: $boff vs. $newpos\n";
    ReadPadding($boff - $newpos);
  }
  
  # bitmaps
  my $bindex = 0;
  for my $off (sort { $a <=> $b } keys %bmaps)
  {
    my $curpos = CurOffset();
    if ($curpos > $off)
    {
      warn "Coll $coll: Jumped past bitmap $bindex! ($curpos vs. $off)\n";
      last;
    }
    if ($off > $curpos)
    {
#         warn "Coll $coll, bitmap $bindex: " . ($off - $curpos) . "\n";
      ReadPadding($off - $curpos);
    }
    
    my $width = ReadSint16();
    my $height = ReadSint16();
    my $bytes_row = ReadSint16();
    warn "Bitmap row mismatch: $bytes_row vs. $width\n" unless ($bytes_row == $width);
    
    {
      my $val = ReadSint16();
      warn "Non-zero padding in coll $coll, bitmap $bindex (offset " . CurOffset() . ")\n" if ($val != 0);
    }
    
    my $column = 0;
    my $transp = 1;
    
    if ($coll < 64)
    {
      $column = 1;
      my $temp = $width;
      $width = $height;
      $height = $temp;
    }
    
    my $rowct = $column ? $width : $height;
    my $rowlen = $column ? $height : $width;
    warn "Bytes-per-row mismatch: $bytes_row vs. $rowlen\n" unless ($bytes_row == $rowlen);

    $out->startTag('bitmap', 'index' => $bindex,
          'width' => $width, 'height' => $height,
          'bytes_per_row' => $bytes_row,
          'column_order' => $column,
          'transparent' => $transp,
          'bit_depth' => 8,
          );
    
    ReadPadding(4 * ($rowct + 1));
    my $bdata = '';      
    for my $col (1..$rowct)
    {
      my $linedata = ReadRaw($rowlen);
      $linedata =~ tr/\x02/\x00/;
      $bdata .= $linedata;
    }
    $out->characters(MIME::Base64::encode_base64($bdata));
    $out->endTag('bitmap');      

    # give bitmap info to low-level shapes
    for my $lindex (@{ $bmaps{$off} })
    {
      $lshs[$lindex][0] = $bindex;
      $lshs[$lindex][1] = $width;
      $lshs[$lindex][2] = $height;
    }
    
    $bindex++;
  }    

  my $index = 0;
  for my $off (sort { $a <=> $b } keys %bmaps)
  {
    for my $lindex (@{ $bmaps{$off} })
    {
      $lshs[$lindex][0] = $index;
    }
    $index++;
  }
  $index = 0;
  for my $linfo (@lshs)
  {
    my ($bindex, $width, $height, $xmirror, $ymirror, $obscure, $wl, $wr, $wt, $wb, $wx, $wy) = @$linfo;
    
    my ($origx, $origy, $keyx, $keyy) = (0, 0, 0, 0);
    my $ww = $wr - $wl;
    my $wh = $wt - $wb;
    if ($ww && $wh)
    {
      my $scalew = $ww / $width;
      my $scaleh = $wh / $height;
      if ((($width > $height) && (abs($wh - ($scalew * $height)) > 1)) ||
          (($height > $width) && (abs($ww - ($scaleh * $width )) > 1))) 
      {
        warn "Inconsistent scale factor: ($ww / $width) vs. ($wh / $height)\n";
      }
      my $scale = ($scalew + $scaleh) / 2;
      $origx = sprintf("%d", -$wl / $scale);
      $origy = sprintf("%d", $wt / $scale);
      $keyx = sprintf("%d", ($wx - $wl) / $scale);
      $keyy = sprintf("%d", ($wt - $wy) / $scale);
    }
        
    $out->emptyTag('low_level_shape', 'index' => $index,
          'x_mirror' => $xmirror, 'y_mirror' => $ymirror,
          'keypoint_obscured' => $obscure,
          'minimum_light_intensity' => 0,
          'bitmap_index' => $bindex,
          'origin_x' => $origx, 'origin_y' => $origy,
          'key_x' => $keyx, 'key_y' => $keyy,
          'world_left' => $wl, 'world_right' => $wr,
          'world_top' => $wt, 'world_bottom' => $wb,
          'world_x0' => $wx, 'world_y0' => $wy,
          );
    $index++;
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


sub UnpackResource
{
  my $datalen = ReadUint32();
  my ($d0, $d1, $d2, $d4) = (0, 0, 0, $datalen);
  my $data = '';
  
  while ($d4 > $d2)
  {
    $d0 = ReadUint8();
    if ($d0 >= 0x80)
    {
      $d0 -= 0x7f;
      $d2 += $d0;
      while ($d0) { $data .= ReadRaw(1); $d0--; }
    }
    else
    {
      $d0 += 3;
      $d1 = ReadRaw(1);
      $d2 += $d0;
      while ($d0) { $data .= $d1; $d0--; }
    }
  }
  
  return $data;
}
