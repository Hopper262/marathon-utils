#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use Image::Magick ();
use Carp ();

our $imgdir = $ARGV[0];
die "Usage: $0 <images-dir> < <map-resource-fork>\n" unless -d $imgdir;

$SIG{__DIE__} = \&Carp::croak;

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

my (@mapinfo, %tiles);
for my $dref (sort { $a->[0] <=> $b->[0] } @datainfo)
{
  my ($off, $name, $id) = @$dref;
  next unless ($name eq 'M' . chr(0x8A) . 'P ');
  
  SetReadSource($dataBlob) if defined $dataBlob;
  ReadPadding($off);
  my $origlen = ReadUint32();
  
  ReadPadding(256);
  my @mapdata;
  for my $row (0..31)
  {
    my @rowdata;
    for my $col (0..31)
    {
      my $tile = uc(unpack 'H4', ReadRaw(2));
      unless (exists $tiles{$tile})
      {
        $tiles{$tile} = Img("$tile.png");
      }
      push(@rowdata, $tile);
    }
    push(@mapdata, [ @rowdata ]);
  }
  push(@mapinfo, [ $id, [ @mapdata ] ]);
}

my $dim = $tiles{'0000'}->Get('width');

for my $mm (@mapinfo)
{
  my ($mapid, $mapdata) = @$mm;
  
  # initialize map
  my $base = Image::Magick->new('size' => (34 * $dim) . 'x' . (34 * $dim));
  $base->ReadImage('canvas:white');
  
  my @grid;
  for my $row (0..31)
  {
    my $y = $dim * $row;
    for my $col (0..31)
    {
      my $x = $dim * $col;
      
      $base->Composite('image' => $tiles{'0000'}, 'x' => $x, 'y' => $y, 'compose' => 'over');
      
      my $tid = $mapdata->[$row][$col];
      next if $tid eq '0000';
      $base->Composite('image' => $tiles{$tid}, 'x' => $x, 'y' => $y, 'compose' => 'over');
    }
  }
  
  my $err = $base->Write(sprintf('level%03d.png', $mapid - 1000));
  die $err if $err;
}

sub Img
{
  my ($path) = @_;
  
  my $img = Image::Magick->new() or die;
  my $err = $img->Read("$imgdir/$path");
  die $err if $err;
  return $img;
}

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
