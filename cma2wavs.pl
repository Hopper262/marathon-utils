#!perl
use strict;
use warnings 'FATAL' => 'all';
use IO::Uncompress::Inflate qw(inflate $InflateError);

# CMA compression is a modified RFC 1950 deflate stream:
# - 4-byte header with uncompressed size, in big-endian format
# - 2-byte RFC 1950 header
# - compressed data blocks
# - no CRC32 at end
seek STDIN, 4, 1;
my $audiodata;
inflate '-' => \$audiodata or die "inflate failed: $InflateError\n";

# MWAV has a 32-byte header followed by PCM data
SetReadSource($audiodata);
my $magic = ReadRaw(4);
die "not an MWAV file" if $magic ne 'MWAV';
my $resource_id = ReadUint32();
my $sound_count = ReadUint32();
ReadPadding(4);

my @sound_info;
for my $i (1..$sound_count)
{
  my $channels = ReadUint16();
  my $bits = ReadUint16();
  my $rate = ReadUint32();
  my $length = ReadUint32();
  my $offset = ReadUint32();
  push(@sound_info, [ $offset, $length, $channels, $bits, $rate ]);
}
my $base = CurOffset();

for my $i (1..$sound_count)
{
  my ($offset, $len, $channels, $bits, $rate) = @{ $sound_info[$i - 1] };
  ReadPadding($offset + $base - CurOffset());
  my $endOffset = CurOffset() + $len;
  
  my $filename = ($sound_count == 1) ? "$resource_id.wav" : "$resource_id-$i.wav";
  my $fh;
  open($fh, '>', $filename) or die "Could not write $filename: $!";
  
  my $bytes_sample = $bits / 8;
  my $data_size = $len;
  
  print $fh "RIFF";                  # ChunkID
  print $fh pack('V', 36 + $data_size);  # ChunkSize
  print $fh "WAVE";                   # Format

  print $fh "fmt ";                   # Subchunk1ID
  print $fh pack('V', 16);            # Subchunk1Size
  print $fh pack('v', 1);             # AudioFormat
  print $fh pack('v', $channels);     # NumChannels
  print $fh pack('V', $rate);         # SampleRate
  print $fh pack('V', $rate * $channels * $bytes_sample);   # ByteRate
  print $fh pack('v', $channels * $bytes_sample);           # BlockAlign
  print $fh pack('v', $bytes_sample * 8);                   # BitsPerSample

  print $fh "data";                   # Subchunk2ID
  print $fh pack('V', $data_size);    # Subchunk2Size
  
  while (CurOffset() < $endOffset)
  {
    for my $i (1..$channels)
    {
      if ($bits == 8)
      {
        print $fh pack('C', ReadUint8());
      }
      elsif ($bits == 16)
      {
        # convert s16be to s16le
        my $val1 = ReadUint8();
        my $val2 = ReadUint8();
        print $fh pack('C', $val2);
        print $fh pack('C', $val1);
      }
      else
      {
        die "Unhandled bits per sample: $bits";
      }
    }
  }
  
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
