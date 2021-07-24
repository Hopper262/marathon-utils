#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use Encode ();
use bytes;

my $outname = $ARGV[0];

binmode STDIN;

# Read MARKer
my $magic = ReadFixedString(4);
die "Not a MARK file" unless $magic eq 'MARK';
my $dataVersion = ReadUint32();
my $entryCount = ReadUint32();
unless ($entryCount)
{
  print STDERR sprintf("No entries, exiting\n");
  exit;
}
# print STDERR sprintf("Finding \%ld entries\n", $entryCount);
my $dataStart = ReadUint32();
die sprintf("Bad offset: \%ld < \%ld", $dataStart, 40088) if $dataStart < 40088;

# my %entryLookup;
# while (CurOffset() < 40088)
# {
#   my $entryStart = ReadUint32();
#   next unless $entryStart > 16;
#   $entryLookup{$entryStart} = CurOffset();
# }
ReadPadding(40088 - CurOffset());

my %entryData;
# my $curEntryCount = 0;
while (CurOffset() < $dataStart)
{
  # $curEntryCount++;
  # my $idx = $entryLookup{CurOffset()} // -1;
  my $un1 = ReadUint32();
  my $dataSize = ReadUint32();
  my $dataOffset = ReadUint32();
  my $un4 = ReadUint32();
  my $un5 = ReadUint32();
  my $un6 = ReadUint32();
  my $pathsize = ReadUint32();
  my $path = ReadFixedString($pathsize);
  die "Bad path format: $path" unless $path =~ /^game:\\/;
  $entryData{$dataOffset + $dataStart} = [ $dataSize, $path ];
  # print STDERR sprintf("\%d. Entry at \%ld: \%s\n  Index: \%ld\n  \%ld - \%ld - \%ld (\%ld - \%ld - \%ld)\n", $curEntryCount, CurOffset(), $path, $idx, $un1, $un2, $un3, $un4, $un5, $un6);
}

for my $off (sort { $a <=> $b } keys %entryData)
{
  die "Bad entry offset: $off" if $off < CurOffset();
  # print STDERR sprintf("Skipping \%ld bytes to \%ld\n", $off - CurOffset(), $off);
  ReadPadding($off - CurOffset());
  
  my $ref = $entryData{$off};
  my @dirs = split(/\\/, $ref->[1]);
  shift @dirs;
  my $filename = pop @dirs;
  
  my $reldir = join('/', @dirs);
  system('mkdir', '-p', $reldir);
  my $relfile = "$reldir/$filename";
  # print STDERR sprintf("Writing $relfile\n");
  my $fh;
  open($fh, '>', $relfile) or die "Could not open $relfile: $!";
  binmode $fh;
  print $fh ReadRaw($ref->[0]);
  close $fh;
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
