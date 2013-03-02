#!/usr/bin/perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Simple ();
use MIME::Base64 ();
use Encode ();
use Carp ();

$SIG{__DIE__} = \&Carp::croak;

our $PAD_BITMAPS = 1;  # pad out bitmaps to 4 bytes, like M2 Shapes file

our $CURCHUNK = '';  # for error logging

binmode STDOUT;

my $xml = XML::Simple::XMLin('-', 'KeyAttr' => [], 'ForceArray' => 1);
my $colls = $xml->{'collection'};
die "No collections found" unless $colls;

my %meta;
my $maxcoll = 31;
for my $cref (@$colls)
{
  my $cindex = Num($cref->{'index'});
  $maxcoll = $cindex if $cindex > $maxcoll;
  
  my $ckey = $cindex . '-' . Num($cref->{'depth'}, 8);
  die "Duplicate chunk: $ckey" if exists $meta{$ckey};
  $CURCHUNK = $ckey;
  
  $meta{$ckey} = { 'size' => 0,
                   'xml'  => $cref,
                   'ctab' => { 'size' => 0, 'color' => 0, 'clut' => 0, 'items' => [] },
                   'hlsh' => { 'count' => 0, 'size' => 0, 'items' => [] },
                   'llsh' => { 'count' => 0, 'size' => 0, 'items' => [] },
                   'bmap' => { 'count' => 0, 'size' => 0, 'items' => [] },
                   };
  my $mref = $meta{$ckey};
  
  MeasureCtab($mref->{'ctab'}, $cref->{'color_table'});
  MeasureHlsh($mref->{'hlsh'}, $cref->{'high_level_shape'});
  MeasureLlsh($mref->{'llsh'}, $cref->{'low_level_shape'});
  MeasureBmap($mref->{'bmap'}, $cref->{'bitmap'});
  $mref->{'size'} = $mref->{'ctab'}{'size'} +
                    $mref->{'hlsh'}{'size'} +
                    $mref->{'llsh'}{'size'} +
                    $mref->{'bmap'}{'size'} +
                    544;
#   print STDERR "Size of $ckey: $csize\n";
}

my $fileoff = 32 * ($maxcoll + 1);
my @chunks_to_write = ();
for my $coll (0..$maxcoll)
{
  WriteSint16(0); # status
  WriteUint16(0); # flags
  for my $depth (8, 16)
  {
    my $ckey = $coll . '-' . $depth;
    $CURCHUNK = $ckey;
    my $ref = $meta{$ckey};
#     print STDERR "Chunk size of $ckey: " . ($ref->{'size'} || 0) . "\n";
    if ($ref && $ref->{'size'})
    {
      WriteSint32($fileoff);
      WriteSint32($ref->{'size'});
      $fileoff += $ref->{'size'};
      push(@chunks_to_write, [ $ckey, $ref ]);
    }
    else
    {
      WriteSint32(-1);
      WriteSint32(0);
    }
  }
  WritePadding(12);
}
for my $chunkinfo (@chunks_to_write)
{
  my $CURCHUNK = $chunkinfo->[0];
  my $mref = $chunkinfo->[1];
  my $def = $mref->{'xml'};
  my $chunkoff = 544;
  
  my $cldf = $def->{'definition'} || [ {} ];
  die "Duplicate definitions for $CURCHUNK" if scalar(@$cldf) > 1;
  $cldf = $cldf->[0];
  WriteSint16($cldf->{'version'}, 3);
  WriteSint16($cldf->{'type'});
  WriteUint16(0);  # flags
  
  WriteSint16($mref->{'ctab'}{'color'});
  WriteSint16($mref->{'ctab'}{'clut'});
  WriteSint32($chunkoff);
  $chunkoff += ($mref->{'ctab'}{'color'} * $mref->{'ctab'}{'clut'} * 8);
  
  for my $type ('hlsh', 'llsh', 'bmap')
  {
    WriteSint16($mref->{$type}{'count'});
    WriteSint32($chunkoff);
    $mref->{$type}{'offset'} = $chunkoff;
    $chunkoff += $mref->{$type}{'size'};
  }
  
  WriteSint16($cldf->{'pixels_to_world'});
  WriteUint32($chunkoff);  # size
  WritePadding(506);
  
  HandleCtab($mref->{'ctab'}, $def->{'color_table'});
  HandleHlsh($mref->{'hlsh'}, $def->{'high_level_shape'});
  HandleLlsh($mref->{'llsh'}, $def->{'low_level_shape'});
  HandleBmap($mref->{'bmap'}, $def->{'bitmap'});
}
exit;


sub MeasureCtab
{
  my ($meta, $def) = @_;
  return unless $def;
  
  my $color = 0;
  my $clut = 0;
  for my $ref (@$def)
  {
    my $idx = Num($ref->{'index'});
    die "Duplicate color table: $CURCHUNK-$idx" if exists $meta->{'ctab'}[$idx];
    $clut = $idx + 1 if $clut <= $idx;
    
    my $clref = $ref->{'color'};
    my $cct = scalar @$clref;
    $color = $cct if $color <= $cct;
    
    $meta->{'items'}[$idx] = [ $cct, $ref ];
  }
  $meta->{'color'} = $color;
  $meta->{'clut'} = $clut;
  $meta->{'size'} = $color * $clut * 8;
} # end MeasureCtab

sub MeasureHlsh
{
  my ($meta, $def) = @_;
  return unless $def;
  
  my $count = 0;
  my $size = 0;
  for my $ref (@$def)
  {
    my $idx = Num($ref->{'index'});
    die "Duplicate high-level shape: $CURCHUNK-$idx" if exists $meta->{'hlsh'}[$idx];
    $count = $idx + 1 if $count <= $idx;
    
    my $fref = $ref->{'frame'} || [];
    my $fct = scalar @$fref;
    
    my $isize = ($fct * 2) + 90;
    $meta->{'items'}[$idx] = [ $isize, $ref ];
    $size += $isize;
  }
  $meta->{'count'} = $count;
  $meta->{'size'} = $size + (4 * $count);
} # end MeasureHlsh

sub MeasureLlsh
{
  my ($meta, $def) = @_;
  return unless $def;
  
  my $count = 0;
  my $size = 0;
  for my $ref (@$def)
  {
    my $idx = Num($ref->{'index'});
    die "Duplicate low-level shape: $CURCHUNK-$idx" if exists $meta->{'llsh'}[$idx];
    $count = $idx + 1 if $count <= $idx;
    
    my $isize = 36;
    $meta->{'items'}[$idx] = [ $isize, $ref ];
    $size += $isize;
  }
  $meta->{'count'} = $count;
  $meta->{'size'} = $size + (4 * $count);
} # end MeasureLlsh

sub MeasureBmap
{
  my ($meta, $def) = @_;
  return unless $def;
  
  my $count = 0;
  my $size = 0;
  for my $ref (@$def)
  {
    my $idx = Num($ref->{'index'});
    die "Duplicate bitmap: $CURCHUNK-$idx" if exists $meta->{'bmap'}[$idx];
    $count = $idx + 1 if $count <= $idx;
    
    my $colorder = (defined($ref->{'column_order'}) && !$ref->{'column_order'}) ? 0 : 1;
    my $width = Num($ref->{'width'});
    my $height = Num($ref->{'height'});
    my $rowct = $colorder ? $width : $height;
    my $datasize = length(MIME::Base64::decode_base64($ref->{'content'}) || '');
    if ($rowct && !$datasize)
    {
      # create blank image
      $ref->{'bytes_per_row'} = -1;
      $ref->{'content'} = '00000000' x $rowct;
      $datasize = 4 * $rowct;
    }
    
    my $isize = 30 + (4 * $rowct) + $datasize;
    my $padding = 0;
    if ($PAD_BITMAPS && ($isize % 4))
    {
      $padding = 4 - ($isize % 4);
      $isize += $padding;
    }
    $meta->{'items'}[$idx] = [ $isize, $ref, $padding ];
    $size += $isize;
  }
  $meta->{'count'} = $count;
  $meta->{'size'} = $size + (4 * $count);
} # end MeasureBmap

sub HandleCtab
{
  my ($meta, $def) = @_;
  return unless $def;
  
  my $color_ct = $meta->{'color'};
  my $clut_ct = $meta->{'clut'};
  
  for my $clut_idx (0..($clut_ct - 1))
  {
    my $ctref = undef;
    my $clutm = $meta->{'items'}[$clut_idx];
    $ctref = $clutm->[1] if $clutm;
    my $clref = $ctref ? $ctref->{'color'} : undef;
    for my $i (0..($color_ct - 1))
    {
      my $iref = $clref->[$i] || {};
      my $flags = 0;
      $flags |= 0x80 if ($iref->{'self_luminescent'});
      WriteUint8($flags);
      WriteUint8($iref->{'value'});
      WriteUint16($iref->{'red'});
      WriteUint16($iref->{'green'});
      WriteUint16($iref->{'blue'});
    }
  }
} # end HandleCtab

sub HandleHlsh
{
  my ($meta, $def) = @_;
  return unless $def;
  
  my $count = $meta->{'count'};
  my $curoff = $meta->{'offset'} + (4 * $count);
  for my $idx (0..($count - 1))
  {
    WriteSint32($curoff);
    $curoff += ($meta->{'items'}[$idx][0] || 0);
  }
  
  for my $idx (0..($count - 1))
  {
    my $iref = $meta->{'items'}[$idx][1] || {};
    
    my $frameref = $iref->{'frame'} || [];
  
    WriteSint16($iref->{'type'});
    WriteUint16(0);  # flags
    
    my $name = Encode::encode("MacRoman", $iref->{'name'} || '');
    my $chrs = length($name);
    WriteUint8($chrs);
    WriteRaw($name);
    WritePadding(33 - $chrs);
    
    WriteSint16($iref->{'number_of_views'});
    WriteSint16($iref->{'frames_per_view'});
    WriteSint16($iref->{'ticks_per_frame'});
    WriteSint16($iref->{'key_frame'});
    WriteSint16($iref->{'transfer_mode'});
    WriteSint16($iref->{'transfer_mode_period'});
    WriteSint16($iref->{'first_frame_sound'});
    WriteSint16($iref->{'key_frame_sound'});
    WriteSint16($iref->{'last_frame_sound'});
    WriteSint16($iref->{'pixels_to_world'});
    WriteSint16($iref->{'loop_frame'});
    WritePadding(28);
    for my $f (@$frameref)
    {
      WriteSint16($f->{'index'});
    }
    WriteSint16(0);
  }
} # end HandleHlsh

sub HandleLlsh
{
  my ($meta, $def) = @_;
  return unless $def;
  
  my $count = $meta->{'count'};
  my $curoff = $meta->{'offset'} + (4 * $count);
  for my $idx (0..($count - 1))
  {
    WriteSint32($curoff);
    $curoff += ($meta->{'items'}[$idx][0] || 0);
  }
  
  for my $idx (0..($count - 1))
  {
    my $iref = $meta->{'items'}[$idx][1] || {};
    
    my $flags = 0;
    $flags |= 0x8000 if ($iref->{'x_mirror'});
    $flags |= 0x4000 if ($iref->{'y_mirror'});
    $flags |= 0x2000 if ($iref->{'keypoint_obscured'});
    WriteUint16($flags);
    WriteFixed($iref->{'minimum_light_intensity'});
    WriteSint16($iref->{'bitmap_index'});
    WriteSint16($iref->{'origin_x'});
    WriteSint16($iref->{'origin_y'});
    WriteSint16($iref->{'key_x'});
    WriteSint16($iref->{'key_y'});
    WriteSint16($iref->{'world_left'});
    WriteSint16($iref->{'world_right'});
    WriteSint16($iref->{'world_top'});
    WriteSint16($iref->{'world_bottom'});
    WriteSint16($iref->{'world_x0'});
    WriteSint16($iref->{'world_y0'});
    WritePadding(8);
  }  
} # end HandleLlsh

sub HandleBmap
{
  my ($meta, $def) = @_;
  return unless $def;
  
  my $count = $meta->{'count'};
  my $curoff = $meta->{'offset'} + (4 * $count);
  for my $idx (0..($count - 1))
  {
    WriteSint32($curoff);
    $curoff += ($meta->{'items'}[$idx][0] || 0);
  }
  
  for my $idx (0..($count - 1))
  {
    my $iref = $meta->{'items'}[$idx][1] || {};
    
    my $rowct = Num($iref->{'column_order'} ? $iref->{'width'} : $iref->{'height'});
    my $rawdata = $iref->{'content'} || '';
    my $data = MIME::Base64::decode_base64($rawdata);

    WriteSint16($iref->{'width'});
    WriteSint16($iref->{'height'});
    WriteSint16($iref->{'bytes_per_row'}, -1);
    my $flags = 0;
    $flags |= 0x8000 unless (defined($iref->{'column_order'}) && !$iref->{'column_order'});
    $flags |= 0x4000 if ($iref->{'transparent'});
    WriteUint16($flags);
    WriteSint16($iref->{'bit_depth'});
    WritePadding(20 + (4 * $rowct));
    WriteRaw($data);
    WritePadding($meta->{'items'}[$idx][2] || 0);
  }  
} # end HandleBmap


sub WriteUint32
{
  print pack('L>', Num(@_));
}
sub WriteSint32
{
  print pack('l>', Num(@_));
}
sub WriteUint16
{
  print pack('S>', Num(@_));
}
sub WriteSint16
{
  print pack('s>', Num(@_));
}
sub WriteUint8
{
  print pack('C', Num(@_));
}
sub WriteFixed
{
  my $num = Num(@_);
  WriteSint32(sprintf("%.0f", $num * 65536.0));
}  
sub WritePadding
{
  print "\0" x $_[0];
}
sub WriteRaw
{
  print @_;
}

sub Num
{
  my ($val, $default) = @_;
  $default = 0 unless defined $default;
  $val = $default unless defined $val && length $val;
  return $val + 0;
} # end Num
