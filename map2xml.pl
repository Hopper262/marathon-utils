#!/usr/bin/perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Writer ();
use Encode ();
use Carp;
use bytes;

our $SAMPLE = 0;

my $out = XML::Writer->new('DATA_MODE' => 1, 'DATA_INDENT' => '  ', 'ENCODING' => 'us-ascii', 'UNSAFE' => 1);
$out->startTag('wadfile');

binmode STDIN;

# Read wad header
my $wadType = ReadUint16();
ReadPadding(2); # data_version
my $wadName = ReadFixedString(64);
ReadPadding(4); # checksum
my $wadSize = ReadUint32() - 128;
my $levelCount = ReadUint16();
my $appSpecificSize = ReadUint16();
my $entrySize = ReadUint16();
my $dirEntrySize = ReadUint16() + $appSpecificSize;
ReadPadding(4); # parent checksum 
ReadPadding(40); # unused

if ($wadType < 2)
{
  $appSpecificSize = 0;
  $entrySize = 12;
  $dirEntrySize = 8;
}

print STDERR "Wad type: $wadType - name: $wadName - size: $wadSize - levels: $levelCount\n";
$out->startTag('wadinfo',
               'type' => $wadType,
               'size' => $wadSize,
               'count' => $levelCount);
$out->raw(escapeForXml($wadName));
$out->endTag('wadinfo');

my $levelData = ReadRaw($wadSize);

my (@levels, @levelNames);
for my $i (0..$levelCount-1)
{
  my $off = ReadUint32();
  my $size = ReadUint32();
  my $name = undef;
  
  if ($dirEntrySize == 84)
  {
    ReadPadding(10);
    $name = ReadFixedString(64);
    ReadPadding(2);
  }
  else
  {
    ReadPadding($dirEntrySize - 8);
  }
  
  $levels[$i] = substr($levelData, $off - 128, $size) if $size;
  $levelNames[$i] = $name if defined $name;
  
#   print STDERR "Level $i: $off, $size\n";
}

for my $lev (0..scalar(@levels)-1)
{
  next unless defined $levels[$lev];
  SetReadSource($levels[$lev]);
  
  $out->startTag('entry', 'index' => $lev);
  
  # make directory
  my $name = $levelNames[$lev];
  if (defined $name)
  {
    $out->startTag('name');
    $out->raw(escapeForXml($name));
    $out->endTag('name');
  }

  my $off = 0;
  my $done = 0;
  until ($done)
  {
    SetReadOffset($off);
    # read chunk header
    my $type = ReadRaw(4);
    $off = ReadUint32();
    $done = 1 unless $off > 0;
    
    my $size = ReadUint32();
    ReadPadding($entrySize - 12);
    my $endOffset = CurOffset() + $size;
    
    my $SHOW_ALL = 0;
    $out->startTag('chunk', 'type' => $type, 'size' => $size) if $size || $SHOW_ALL;
    
    if ($size)
    {
      if ($type eq 'NAME')
      {
        $out->characters(ReadFixedString($size));
      }
      elsif ($type eq 'LINS') # lines
      {
        my $index = 0;
        while (CurOffset() < $endOffset)
        {
          $out->emptyTag('line', 'index' => $index++,
                         'endpoint1' => ReadSint16(),
                         'endpoint2' => ReadSint16(),
                         'flags' => ReadUint16(),
                         'length' => ReadSint16(),
                         'highest_floor' => ReadSint16(),
                         'lowest_ceiling' => ReadSint16(),
                         'cw_side' => ReadSint16(),
                         'ccw_side' => ReadSint16(),
                         'cw_poly' => ReadSint16(),
                         'ccw_poly' => ReadSint16(),
                         );
          ReadPadding(12);
          last if $SAMPLE;
        }
      }
      elsif ($type eq 'EPNT') # endpoints
      {
        my $index = 0;
        while (CurOffset() < $endOffset)
        {
          $out->emptyTag('endpoint', 'index' => $index++,
                         'flags' => ReadUint16(),
                         'highest_floor' => ReadSint16(),
                         'lowest_ceiling' => ReadSint16(),
                         'x' => ReadSint16(),
                         'y' => ReadSint16(),
                         'x_transformed' => ReadSint16(),
                         'y_transformed' => ReadSint16(),
                         'poly' => ReadSint16(),
                         );
          last if $SAMPLE;
        }
      }
      elsif ($type eq 'PNTS') # points
      {
        my $index = 0;
        while (CurOffset() < $endOffset)
        {
          $out->emptyTag('point', 'index' => $index++,
                         'x' => ReadSint16(),
                         'y' => ReadSint16(),
                         );
          last if $SAMPLE;
        }
      }
      elsif ($type eq 'POLY') # polys
      {
        my $index = 0;
        while (CurOffset() < $endOffset)
        {
          $out->emptyTag('polygon', 'index' => $index++,
                         'type' => ReadSint16(),
                         'flags' => ReadUint16(),
                         'permutation' => ReadSint16(),
                         'vertex_count' => ReadUint16(),
                         genList('endpoint_index_', \&ReadSint16, 8),
                         genList('line_index_', \&ReadSint16, 8),
                         genShape('floor_texture_', ReadUint16()),
                         genShape('ceiling_texture_', ReadUint16()),
                         'floor_height' => ReadSint16(),
                         'ceiling_height' => ReadSint16(),
                         'floor_lightsource_index' => ReadSint16(),
                         'ceiling_lightsource_index' => ReadSint16(),
                         'area' => ReadSint32(),
                         'first_object' => ReadSint16(),
                         'first_exclusion_zone_index' => ReadSint16(),
                         'line_exclusion_zone_count' => ReadSint16(),
                         'point_exclusion_zone_count' => ReadSint16(),
                         'floor_transfer_mode' => ReadSint16(),
                         'ceiling_transfer_mode' => ReadSint16(),
                         genList('adjacent_polygon_index_', \&ReadSint16, 8),
                         'first_neighbor_index' => ReadSint16(),
                         'neighbor_count' => ReadSint16(),
                         'center_x' => ReadSint16(),
                         'center_y' => ReadSint16(),
                         genList('side_index_', \&ReadSint16, 8),
                         'floor_origin_x' => ReadSint16(),
                         'floor_origin_y' => ReadSint16(),
                         'ceiling_origin_x' => ReadSint16(),
                         'ceiling_origin_y' => ReadSint16(),
                         'media_index' => ReadSint16(),
                         'media_lightsource_index' => ReadSint16(),
                         'sound_source_indexes' => ReadSint16(),
                         'ambient_sound_image_index' => ReadSint16(),
                         'random_sound_image_index' => ReadSint16(),
                         );
          ReadPadding(2);
          last if $SAMPLE;
        }
      }
      elsif ($type eq 'SIDS') # sides
      {
        my $index = 0;
        while (CurOffset() < $endOffset)
        {
          $out->emptyTag('side', 'index' => $index++,
                         'type' => ReadSint16(),
                         'flags' => ReadUint16(),
                         'primary_x' => ReadSint16(),
                         'primary_y' => ReadSint16(),
                         genShape('primary_tex_', ReadUint16()),
                         'secondary_x' => ReadSint16(),
                         'secondary_y' => ReadSint16(),
                         genShape('secondary_tex_' => ReadUint16()),
                         'transparent_x' => ReadSint16(),
                         'transparent_y' => ReadSint16(),
                         genShape('transparent_tex_', ReadUint16()),
                         'exclusion_e0_x' => ReadSint16(),
                         'exclusion_e0_y' => ReadSint16(),
                         'exclusion_e1_x' => ReadSint16(),
                         'exclusion_e1_y' => ReadSint16(),
                         'exclusion_e2_x' => ReadSint16(),
                         'exclusion_e2_y' => ReadSint16(),
                         'exclusion_e3_x' => ReadSint16(),
                         'exclusion_e3_y' => ReadSint16(),
                         'panel_type' => ReadSint16(),
                         'panel_permutation' => ReadSint16(),
                         'primary_transfer' => ReadSint16(),
                         'secondary_transfer' => ReadSint16(),
                         'transparent_transfer' => ReadSint16(),
                         'poly' => ReadSint16(),
                         'line' => ReadSint16(),
                         'primary_light' => ReadSint16(),
                         'secondary_light' => ReadSint16(),
                         'transparent_light' => ReadSint16(),
                         'ambient_delta' => ReadSint32(),
                         );
          ReadPadding(2);
          last if $SAMPLE;
        }
      }
      elsif ($type eq 'NOTE') # annotations
      {
        my $index = 0;
        while (CurOffset() < $endOffset)
        {
          $out->startTag('annotation', 'index' => $index++,
                         'type' => ReadSint16(),
                         'location_x' => ReadSint16(),
                         'location_y' => ReadSint16(),
                         'polygon_index' => ReadSint16(),
                         );
          $out->raw(escapeForXml(ReadFixedString(64)));
          $out->endTag('annotation');
          last if $SAMPLE;
        }
      }
      elsif ($type eq 'medi') # media
      {
        my $index = 0;
        while (CurOffset() < $endOffset)
        {
          $out->emptyTag('media', 'index' => $index++,
                         'type' => ReadSint16(),
                         'flags' => ReadUint16(),
                         'light_index' => ReadSint16(),
                         'current_direction' => ReadSint16(),
                         'current_magnitude' => ReadSint16(),
                         'low' => ReadSint16(),
                         'high' => ReadSint16(),
                         'origin_x' => ReadSint16(),
                         'origin_y' => ReadSint16(),
                         'height' => ReadSint16(),
                         'minimum_light_intensity' => ReadFixed(),
                         genShape('transparent_tex_', ReadUint16()),
                         'transfer_mode' => ReadSint16(),
                         );
          ReadPadding(4);
          last if $SAMPLE;
        }
      }
      elsif ($type eq 'PLAT') # platforms
      {
        my $index = 0;
        while (CurOffset() < $endOffset)
        {
          $out->emptyTag('platform', 'index' => $index++,
                         'type' => ReadSint16(),
                         'static_flags' => ReadUint32(),
                         'speed' => ReadSint16(),
                         'delay' => ReadSint16(),
                         'minimum_floor_height' => ReadSint16(),
                         'maximum_floor_height' => ReadSint16(),
                         'minimum_ceiling_height' => ReadSint16(),
                         'maximum_ceiling_height' => ReadSint16(),
                         'polygon_index' => ReadSint16(),
                         'dynamic_flags' => ReadUint16(),
                         'floor_height' => ReadSint16(),
                         'ceiling_height' => ReadSint16(),
                         'ticks_until_restart' => ReadSint16(),
                         genMultiList('endpoint_owner_', 8,
                            '_first_polygon_index' => \&ReadSint16,
                            '_polygon_index_count' => \&ReadSint16,
                            '_first_line_index' => \&ReadSint16,
                            '_line_index_count' => \&ReadSint16,
                            ),
                         'parent_platform_index' => ReadSint16(),
                         'tag' => ReadSint16(),
                         );
          ReadPadding(44);
          last if $SAMPLE;
        }
      }
      elsif ($type eq 'plat') # old platforms
      {
        my $index = 0;
        while (CurOffset() < $endOffset)
        {
          $out->emptyTag('platform', 'index' => $index++,
                         'type' => ReadSint16(),
                         'speed' => ReadSint16(),
                         'delay' => ReadSint16(),
                         'maximum_height' => ReadSint16(),
                         'minimum_height' => ReadSint16(),
                         'static_flags' => ReadUint32(),
                         'polygon_index' => ReadSint16(),
                         'tag' => ReadSint16(),
                         );
          ReadPadding(14);
          last if $SAMPLE;
        }
      }
      elsif ($type eq 'Minf') # static info
      {
        my $index = 0;
        while (CurOffset() < $endOffset)
        {
          my @tags = (
               'environment_code' => ReadSint16(),
               'physics_model' => ReadSint16(),
               'song_index' => ReadSint16(),
               'mission_flags' => ReadSint16(),
               'environment_flags' => ReadSint16(),
                     );
          ReadPadding(8);
          $name = ReadFixedString(66);
          push(@tags, 'entry_point_flags' => ReadUint32());
          
          $out->startTag('mapinfo', 'index' => $index++, @tags);
          $out->raw(escapeForXml($name));
          $out->endTag('mapinfo');
          last if $SAMPLE;
        }
      }
    }
    $out->endTag('chunk') if $size || $SHOW_ALL;
  }
  
  $out->endTag('entry');
  last if $SAMPLE;
}

$out->endTag('wadfile');
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
  confess "Can't set offset for piped data" unless defined $BLOB;
  confess "Bad offset for data" if (($off < 0) || ($off > $BLOBlen));
  $BLOBoff = $off;
}
sub CurOffset
{
  return $BLOBoff;
}
sub ReadRaw
{
  my ($size, $nofail) = @_;
  confess "Can't read negative size" if $size < 0;
  return '' if $size == 0;
  if (defined $BLOB)
  {
    my $left = $BLOBlen - $BLOBoff;
    if ($size > $left)
    {
      return undef if $nofail;
      confess "Not enough data in blob (offset $BLOBoff, length $BLOBlen)";
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
      confess "Failed to read $size bytes";
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

sub ReadFixedString
{
  my ($size) = @_;
  return '' unless $size > 0;
  my $raw = ReadRaw($size);
  my @parts = split("\0", $raw);
  return Encode::decode('MacRoman', $parts[0]);
}

sub genShape {
  my ($prefix, $val) = @_;
  
  my ($shp, $coll, $clut) = (-1, -1, -1);
  if ($val != 65535)
  {
    $shp = $val & 0xff;
    $coll = ($val >> 8) & 0x1f;
    $clut = ($val >> 13) & 0x7;
  }
  
  return ($prefix . 'shape', $shp,
          $prefix . 'collection', $coll,
          $prefix . 'clut', $clut);
}

sub genList {
  my ($prefix, $func, $ct) = @_;
  return genMultiList($prefix, $ct, '' => $func);
}

sub genMultiList {
  my ($prefix, $ct, @rest) = @_;
  my @ret;
  for my $i (0..($ct - 1))
  {
    my @parts = @rest;
    while (scalar @parts)
    {
      my $suffix = shift @parts;
      my $func = shift @parts;
      push(@ret, $prefix . $i . $suffix, $func->());
    }
  }
  return @ret;
}

sub escapeForXml {
  my ($data) = @_;

  if ($data =~ /[\&\<\>\"]/) {
    $data =~ s/\&/\&amp\;/g;
    $data =~ s/\</\&lt\;/g;
    $data =~ s/\>/\&gt\;/g;
    $data =~ s/\"/\&quot\;/g;
  }
  
  $data =~ s/([^\x20-\x7E])/sprintf('&#x%02X;', ord($1))/ge;
  
  return $data;
}
