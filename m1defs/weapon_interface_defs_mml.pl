#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/io.subs";
require "$FindBin::Bin/mml.subs";

SetReadOffset(3828);
warn "Starting at: " . CurOffset() . "\n";

my @weps;
for my $wepnum (0..6)
{
  ReadPadding(2);  # item id - unused
  
  my %hash = (
    'index' => $wepnum,
    'shape' => ReadFrame(),
    'start_y' => ReadSint16(),
    'end_y' => ReadSint16(),
    'start_x' => ReadSint16(),
    'end_x' => ReadSint16(),
    'top' => ReadSint16(),
    'left' => ReadSint16(),
    'multiple' => ReadBool(),
    );
  ReadPadding(1);
    
  ### Fill out multiple-shape info -- hardcoded in M1?
  if ($hash{'multiple'} eq 'true')
  {
    $hash{'multiple_shape'} = 15;
    $hash{'multiple_unusable_shape'} = 9;
    $hash{'multiple_delta_x'} = -97;    # measured from screenshot
    $hash{'multiple_delta_y'} = 0;
  }
  
  my @ammos;
  for my $i (0..1)
  {
    my %ammo = (
      'index' => $i,
      'type' => ReadSint16(),
      'left' => ReadSint16(),
      'top' => ReadSint16(),
      'across' => ReadSint16(),
      'down' => ReadSint16(),
      'delta_x' => ReadSint16(),
      'delta_y' => ReadSint16(),
      'bullet_shape' => ReadFrame(),
      'empty_shape' => ReadFrame(),
      'right_to_left' => ReadBool(),
      );
      ReadPadding(1);
    push(@ammos, \%ammo);
  }
  $hash{'ammo'} = \@ammos;
  push(@weps, \%hash);
}
warn "Ending at: " . CurOffset() . "\n";
print FormatMML({ 'interface' => { 'weapon' => \@weps } });
