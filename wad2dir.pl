#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use Encode ();
use bytes;

my $outname = $ARGV[0];

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

$outname = "$wadName export" unless $outname;
print STDERR "Exporting to $outname\n";

for my $lev (0..scalar(@levels)-1)
{
  next unless defined $levels[$lev];
  SetReadSource($levels[$lev]);
  
  # make directory
  my $name = $levelNames[$lev];
  unless (defined $name)
  {
    # search for name chunk
    my $off = 0;
    my $done = 0;
    until ($done)
    {
      SetReadOffset($off);
      # read chunk header
      my $type = ReadRaw(4);
      $off = ReadUint32();
      $done = 1 unless $off > 0;
      next unless $type eq 'NAME';
      
      my $size = ReadUint32();
      ReadPadding($entrySize - 12);
      $name = ReadFixedString($size);
      last;
    }
  }
  
  print STDERR "Processing level $lev: (@{[ $name || 'Untitled' ]})\n";
  my $dirname = sprintf("$outname/%02d", $lev);
  $dirname .= " $name" if defined $name;
  
  my $off = 0;
  my $done = 0;
  until ($done)
  {
    SetReadOffset($off);
    # read chunk header
    my $type = ReadRaw(4);
    my $str_type = Encode::decode('MacRoman', $type);
    my $filename = "$dirname/$str_type.dat";
    $off = ReadUint32();
    $done = 1 unless $off > 0;
    my $chunkSize = ReadUint32();
    next unless $chunkSize;
    ReadPadding($entrySize - 12);
    
    print STDERR "Chunk '$str_type' - size $chunkSize\n";
    
    my $fh;
    mkdir $outname;
    mkdir $dirname;
    open($fh, '>', $filename) or die;
    binmode $fh;
    print $fh ReadRaw($chunkSize);
    close $fh;
  }
}
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

sub ReadFixedString
{
  my ($size) = @_;
  return '' unless $size > 0;
  my $raw = ReadRaw($size);
  my @parts = split("\0", $raw);
  return Encode::decode('MacRoman', $parts[0]);
}
