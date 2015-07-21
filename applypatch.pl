#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use XML::Simple ();

binmode STDOUT;

my $ref = XML::Simple::XMLin('-', 'KeyAttr' => []);
my $colls = $ref->{'collection'};
die "No collections found in shapes XML\nUsage: $0 <patch-xml> [<patch-xml> ...] < <shapes-xml>\n" unless $colls;

warn "Warning: no patch files given\nUsage: $0 <patch-xml> [<patch-xml> ...] < <shapes-xml>\n" unless scalar @ARGV;

for my $patchfile (@ARGV)
{
  warn "Skipping missing file: $patchfile\n" unless -e $patchfile;
  
  my $patch = XML::Simple::XMLin($patchfile, 'KeyAttr' => []);
  my $pcolls = $ref->{'collection'};
  die "No collections found in patch XML ($patchfile)\nUsage: $0 <patch-xml> [<patch-xml> ...] < <shapes-xml>\n" unless $pcolls;
  
  # tbd
}

print XML::Simple::XMLout($ref, 'AttrIndent' => 1, 'RootName' => 'shapes');
