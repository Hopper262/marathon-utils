#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use Encode ();
use bytes;

## Sources of information:
## https://www.arkem.org/xbox360-file-reference.pdf
## https://free60.org/System-Software/Formats/STFS/

my $outname = $ARGV[0] // '.';

binmode STDIN;

my $magic = ReadFixedString(4);
die "Not a LIVE file" unless $magic eq 'LIVE';
ReadPadding(256); # signature
ReadPadding(296); # blank
ReadPadding(256); # license data
ReadPadding(20);  # SHA1
ReadUint32();     # entry ID
my $contentType = ReadUint32();
warn "Warning: content type is not arcade title" unless $contentType == 0xD0000;
ReadUint32();     # metadata version
ReadUint64();     # content size
ReadPadding(37);  # skip various stuff
my $volDescSize = ReadUint8();
die "This file's volume descriptor is not supported" unless $volDescSize == 36;
ReadPadding(1);   # reserved
my $blockSep = ReadUint8();
my $fileTableBlockCount = ReadUint16LE();
my $fileTableBlockNumber = ReadUint24LE();
die "File listing at block > 0 not supported" unless $fileTableBlockNumber == 0;

# skip to first data block
SetReadOffset(0xC000);

# read file listing
my %directories = ( '-1' => $outname);
my @files = ();
my $fileId = -1;
while (1) {
  $fileId++;
  my $fileName = ReadFixedString(40);
  my $fileLenPlusFlags = ReadUint8();
  my $numBlocks = ReadUint24LE();
  my $numBlocksCopy = ReadUint24LE();
  die "Number of blocks mismatch: $numBlocks vs. $numBlocksCopy for file ID $fileId" if $numBlocks != $numBlocksCopy;
  my $startBlock = ReadUint24LE();
  my $parentDir = ReadSint16();
  my $fileSize = ReadUint32();
  my $updatedTimestamp = ReadSint32();
  my $accessedTimestamp = ReadSint32();

  last unless length $fileName;

  die "Unexpected directory reference: $parentDir" unless exists $directories{$parentDir};
  my $fullPath = $directories{$parentDir} . '/' . $fileName;

  my $fileLen = $fileLenPlusFlags & 63;
  die "Unexpected file length: calculated @{[ length($fileName) ]}, read $fileLen" unless length($fileName) == $fileLen;
  my $isConsecutive = ($fileLenPlusFlags & 64) == 64;
  my $isDir = ($fileLenPlusFlags & 128) == 128;
  if ($isDir) {
    die "Unexpected block size $numBlocks for directory ID $fileId" unless $numBlocks == 0;
    die "Unexpected file size $fileSize for directory ID $fileId" unless $fileSize == 0;
    $directories{$fileId} = $fullPath;
  } else {
    die "File size $fileSize too large for block size $numBlocks for file ID $fileId" if $fileSize > ($numBlocks * 0x1000);
    push(@files, {
      'ID' => $fileId,
      'start' => $startBlock,
      'end' => $startBlock + $numBlocks - 1,
      'bytes' => $fileSize,
      'path' => $fullPath,
    });
  }
}

# check that file blocks do not overlap
my $lastBlockSeen = $fileTableBlockCount - 1;
for my $file (sort { return $a->{'start'} - $b->{'start'} } @files) {
  next unless $file->{'bytes'} > 0;
  die "Data block $lastBlockSeen reused for file ID $file->{'ID'}" unless $file->{'start'} > $lastBlockSeen;
  $lastBlockSeen = $file->{'end'};
}

# create directory structure
for my $dirId (sort { $a <=> $b } keys %directories) {
  my $dirPath = $directories{$dirId};
  next if -d $dirPath;
  die "Could not make directory $dirPath" unless mkdir $dirPath;
}

# read and create files
for my $file (sort { return $a->{'start'} - $b->{'start'} } @files) {
  my $fh;
  open($fh, '>', $file->{'path'}) or die "Could not write $file->{'path'}: $!";
  binmode $fh;
  if ($file->{'bytes'} > 0) {
    my $block = $file->{'start'};
    my $bytesToWrite = $file->{'bytes'};
    while ($bytesToWrite > 0) {
      my $bytesToRead = 0x1000;
      $bytesToRead = $bytesToWrite if $bytesToWrite < $bytesToRead;
      SetReadOffset(BlockToOffset($block++));
      print $fh ReadRaw($bytesToRead);
      $bytesToWrite -= $bytesToRead;
    }
  }
  close $fh;
}
exit;

sub BlockToOffset
{
  my ($blockNum) = @_;

  my $blockCount = $blockNum;

  # 1 hash block occurs before each group of 170 data blocks
  my $hashTables = 1 + int($blockNum / 170);
  $blockCount += $hashTables;

  # 1 higher-level hash block occurs before each group
  # of 170 lower-level hash blocks, except the first one
  # occurs before the *second* lower-level hash block
  while ($hashTables >= 2) {
    $hashTables = 1 + int(($hashTables - 1) / 170);
    $blockCount += $hashTables;
  }

  return 0xB000 + (0x1000 * $blockCount);
}

sub ReadUint64
{
  return ReadPacked('Q>', 8);
}
sub ReadSint64
{
  return ReadPacked('q>', 8);
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

sub ReadUint16LE
{
  return ReadPacked('S<', 2);
}
sub ReadUint24LE
{
  return ReadPacked('S<', 2) + (ReadPacked('C', 1) * 65536);
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
  unless (defined $BLOB) {
    die "Can't rewind piped data" unless $off >= $BLOBoff;
    ReadPadding($off - $BLOBoff);
  } else {
    die "Bad offset for data" if (($off < 0) || ($off > $BLOBlen));
    $BLOBoff = $off;
  }
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
  return $parts[0] // '';
}
