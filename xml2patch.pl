#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Simple ();

binmode STDOUT;

my $ref = XML::Simple::XMLin('-', 'KeyAttr' => [], 'ForceArray' => 1);

my $colls = $ref->{'collection'};
die "No collections found" unless $colls;
$colls = [ $colls ] if ref($colls) eq 'HASH';

for my $cref (@$colls)
{
  WriteSint32($cref->{'index'});
  WriteSint32($cref->{'depth'}, 8);
  
  HandleCldf($cref->{'definition'});
  HandleCtab($cref->{'color_table'});
  HandleHlsh($cref->{'high_level_shape'});
  HandleLlsh($cref->{'low_level_shape'});
  HandleBmap($cref->{'bitmap'});
  
  WriteRaw('endc');
}
exit;

sub HandleCldf
{
  my ($def) = @_;
  return unless $def;
  if (ref($def) eq 'ARRAY')
  {
    HandleCldf($def->[0]);
    return;
  }
  
  WriteRaw('cldf');
  WriteSint16($def->{'version'}, 3);
  WriteSint16($def->{'type'});
  WriteUint16(0);  # flags (unused)
  WriteSint16($def->{'color_count'});
  WriteSint16($def->{'clut_count'});
  WriteSint32($def->{'color_table_offset'});
  WriteSint16($def->{'high_level_shape_count'});
  WriteSint32($def->{'high_level_shape_offset_table_offset'});
  WriteSint16($def->{'low_level_shape_count'});
  WriteSint32($def->{'low_level_shape_offset_table_offset'});
  WriteSint16($def->{'bitmap_count'});
  WriteSint32($def->{'bitmap_offset_table_offset'});
  WriteSint16($def->{'pixels_to_world'});
  WriteUint32(0);  # size
  WritePadding(506);
} # end HandleCldf

sub HandleCtab
{
  my ($def) = @_;
  return unless $def;
  if (ref($def) eq 'ARRAY')
  {
    for my $c (@$def)
    {
      HandleCtab($c);
    }
    return;
  }
  
  WriteRaw('ctab');
  WriteSint32($def->{'index'});
  my $colors = $def->{'color'};
  $colors = [ $colors ] unless (ref($colors) eq 'ARRAY');
  for my $c ($colors)
  {
    my $flags = 0;
    $flags |= 0x80 if ($c->{'self_luminescent'});
    WriteUint8($flags);
    WriteUint8($c->{'value'});
    WriteUint16($c->{'red'});
    WriteUint16($c->{'green'});
    WriteUint16($c->{'blue'});
  }
} # end HandleCtab

sub HandleHlsh
{
  my ($def) = @_;
  return unless $def;
  if (ref($def) eq 'ARRAY')
  {
    for my $c (@$def)
    {
      HandleHlsh($c);
    }
    return;
  }
  
  my $frameref = $def->{'frame'} || [];
  $frameref = [ $frameref ] unless (ref($frameref) eq 'ARRAY');
  
  WriteRaw('hlsh');
  WriteSint32($def->{'index'});
  WriteSint32(90 + (2 * scalar @$frameref));  # size
  
  WriteSint16($def->{'type'});
  WriteUint16(0);  # flags
  
  my $name = $def->{'name'} || '';
  my $chrs = length($name);
  WriteUint8($chrs);
  WriteRaw($name);
  WritePadding(33 - $chrs);
  
  WriteSint16($def->{'number_of_views'});
  WriteSint16($def->{'frames_per_view'});
  WriteSint16($def->{'ticks_per_frame'});
  WriteSint16($def->{'key_frame'});
  WriteSint16($def->{'transfer_mode'});
  WriteSint16($def->{'transfer_mode_period'});
  WriteSint16($def->{'first_frame_sound'});
  WriteSint16($def->{'key_frame_sound'});
  WriteSint16($def->{'last_frame_sound'});
  WriteSint16($def->{'pixels_to_world'});
  WriteSint16($def->{'loop_frame'});
  WritePadding(28);
  for my $f (@$frameref)
  {
    WriteSint16($f->{'index'});
  }
  WriteSint16(0);
} # end HandleHlsh

sub HandleLlsh
{
  my ($def) = @_;
  return unless $def;
  if (ref($def) eq 'ARRAY')
  {
    for my $c (@$def)
    {
      HandleLlsh($c);
    }
    return;
  }
  
  WriteRaw('llsh');
  WriteSint32($def->{'index'});
  my $flags = 0;
  $flags |= 0x8000 if ($def->{'x_mirror'});
  $flags |= 0x4000 if ($def->{'y_mirror'});
  $flags |= 0x2000 if ($def->{'keypoint_obscured'});
  WriteUint16($flags);
  WriteFixed($def->{'minimum_light_intensity'});
  WriteSint16($def->{'bitmap_index'});
  WriteSint16($def->{'origin_x'});
  WriteSint16($def->{'origin_y'});
  WriteSint16($def->{'key_x'});
  WriteSint16($def->{'key_y'});
  WriteSint16($def->{'world_left'});
  WriteSint16($def->{'world_right'});
  WriteSint16($def->{'world_top'});
  WriteSint16($def->{'world_bottom'});
  WriteSint16($def->{'world_x0'});
  WriteSint16($def->{'world_y0'});
  WritePadding(8);
} # end HandleLlsh

sub HandleBmap
{
  my ($def) = @_;
  return unless $def;
  if (ref($def) eq 'ARRAY')
  {
    for my $c (@$def)
    {
      HandleBmap($c);
    }
    return;
  }
  
  my $rowct = Num($def->{'column_order'} ? $def->{'width'} : $def->{'height'});
  my $rawdata = $def->{'content'} || '';
  if ($rowct && !length($rawdata))
  {
    $def->{'bytes_per_row'} = -1;
    $rawdata = '00000000' x $rowct;
  }
  my $data = pack('H*', $rawdata);
  
  WriteRaw('bmap');
  WriteSint32($def->{'index'});
  WriteSint32(30 + (4 * $rowct) + length($data));
  
  WriteSint16($def->{'width'});
  WriteSint16($def->{'height'});
  WriteSint16($def->{'bytes_per_row'}, -1);
  my $flags = 0;
  $flags |= 0x8000 unless (defined($def->{'column_order'}) && !$def->{'column_order'});
  $flags |= 0x4000 if ($def->{'transparent'});
  WriteUint16($flags);
  WriteSint16($def->{'bit_depth'});
  WritePadding(20 + (4 * $rowct));
  WriteRaw($data);
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
  $val = $default unless defined $val;
  return $val + 0;
} # end Num
