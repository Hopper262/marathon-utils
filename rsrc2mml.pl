#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Simple ();
use Encode ();

my $m1 = 0;
my @m1_colorlookup = (
    (0..13),
    -1,   # terminal background?
    16,   # terminal border background
    17,   # terminal border text
    14,   # white
    15,   # invalid weapon
  );
my @m1_rectlookup = (
    -1,   # top of HUD
    -1,   # left of game
    -1,   # right of game
    -1,   # bottom left
    -1,   # unimplemented compass
     0,   # player name
     1,   # oxygen
     2,   # shield
     3,   # motion sensor
     4,   # microphone
    -1,   # area near mic
    30,   # blinking light
     5,   # inventory
     6,   # weapons
    -1,   # beta button in nameplate
    -1,   # beta button in nameplate
    -1,   # beta button in nameplate
    -1,   # beta button in nameplate
    -1,   # beta button in nameplate
    21,   # terminal header bar
    22,   # terminal footer bar
    20,   # game/terminal area
    23,   # terminal full page text
    24,   # terminal checkpoint map
    25,   # terminal checkpoint text
    26,   # terminal logon graphic
    27,   # terminal logon title
    28,   # terminal logon location
    29,   # respawn indicator
     7,   # new game
     8,   # load game
     9,   # gather
    10,   # join
    11,   # preferences
    12,   # replay
    13,   # save film
    14,   # replay saved
    15,   # credits
    16,   # quit
    17,   # center sound
    -1,   # above inventory
    -1,   # below inventory
    -1,   # bottom right
  );



binmode STDIN;
binmode STDOUT, ':utf8';

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
    my $id = ReadSint16();
    ReadPadding(2);
    my $itemOff = $dataOff + (ReadUint32() & 0xffffff);
    
    $m1 = 1 if ($name eq 'clut' && $id == 129);
    
    push(@datainfo, [ $itemOff, $name, $id ]);
    ReadPadding(4);
  }
}

my (%interface, @stringsets);
for my $dref (sort { $a->[0] <=> $b->[0] } @datainfo)
{
  my ($off, $name, $id) = @$dref;
  
  my $is_color = ($name eq 'clut' && $id == 130);
  my $is_rect  = ($name eq 'nrct' && $id == 128);
  my $is_font  = ($name eq 'finf' && $id == 128);
  my $is_str   = ($name eq 'STR#');
  next unless ($is_color || $is_rect || $is_font || $is_str);
  
  SetReadSource($dataBlob);
  ReadPadding($off);
  my $datalen = ReadUint32();
  
  if ($is_color)
  {
    my @colors;
    ReadPadding(6);
    my $ct = ReadUint16() + 1;
    for my $i (1..$ct)
    {
      ReadPadding(2);
      my $idx = $i - 1;
      if ($m1)
      {
        $idx = $m1_colorlookup[$idx];
      }
      push(@colors, {
              'index' => $idx,
              'red' => ReadUint16() / 65535,
              'green' => ReadUint16() / 65535,
              'blue' => ReadUint16() / 65535,
            });
      pop @colors if $idx < 0;
    }
    $interface{'color'} = \@colors;
  }
  elsif ($is_rect)
  {
    my @rects;
    my $ct = ReadUint16();    
    for my $i (1..$ct)
    {
      my $idx = $i - 1;
      if ($m1)
      {
        $idx = $m1_rectlookup[$idx];
      }
      push(@rects, {
              'index' => $idx,
              'top' => ReadSint16(),
              'left' => ReadSint16(),
              'bottom' => ReadSint16(),
              'right' => ReadSint16(),
            });
      pop @rects if $idx < 0;
    }
    $interface{'rect'} = \@rects;
  }
  elsif ($is_font)
  {
    my @fonts;
    my $ct = ReadUint16();
    for my $i (1..$ct)
    {
      my $idx = $i - 1;
      push(@fonts, {
              'index' => $idx,
              'file' => '#' . ReadUint16(),
              'style' => ReadUint16(),
              'size' => ReadUint16(),
            });
    }
    $interface{'font'} = \@fonts;
  }
  elsif ($is_str)
  {
    my @strings;
    my $ct = ReadUint16();
    for my $i (1..$ct)
    {
      my $idx = $i - 1;
      push(@strings, {
              'index' => $idx,
              '_content' => ReadPStr(),
            });
    }
    push(@stringsets, { 'index' => $id, 'string' => \@strings });
  }
}

print FormatMML({ 'interface' => \%interface,
                  'stringset' => \@stringsets });
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
    unless (defined $rsize)
    {
      return undef if $nofail;
      die $!;
    }
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

sub ReadPStr
{
  my $strlen = ReadUint8();
  my $str = ReadRaw($strlen);
  return Encode::decode("MacRoman", $str);
}


sub FormatMML
{
  my ($hashref) = @_;
  
  return XML::Simple::XMLout($hashref, 
                             'RootName' => 'marathon',
                             'KeyAttr' => [],
                             'ContentKey' => '_content',
                             );
}



