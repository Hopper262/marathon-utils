#!/usr/bin/perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Writer ();
use Encode ();

my $out = XML::Writer->new('DATA_MODE' => 1, 'DATA_INDENT' => '  ', 'ENCODING' => 'us-ascii', 'UNSAFE' => 1);
$out->startTag('string_resources');


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

for my $dref (sort { $a->[0] <=> $b->[0] } @datainfo)
{
  my ($off, $name, $id) = @$dref;
  
  next unless ($name eq 'STR ' || $name eq 'STR#');
  SetReadSource($dataBlob);
  ReadPadding($off);
  my $datalen = ReadUint32();
  
  if ($name eq 'STR ')
  {
    $out->startTag('string', 'index' => $id);
    $out->characters(ReadPStr());
    $out->endTag('string');
  }
  else # STR#
  {
    $out->startTag('stringset', 'index' => $id);
    my $numstrings = ReadUint16();
    for my $idx (0..($numstrings - 1))
    {
      $out->startTag('string', 'index' => $idx);
      # I want some more escaping than XML::Writer's defaults
      $out->raw(escapeForXml(ReadPStr()));
      $out->endTag('string');
    }
    $out->endTag('stringset');
  }
}

$out->endTag('string_resources');
$out->end();
exit;



sub ReadPStr
{
  my $strlen = ReadUint8();
  my $str = ReadRaw($strlen);
  return Encode::decode("MacRoman", $str);
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
