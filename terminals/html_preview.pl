#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use HTML::Entities ();
use XML::Simple ();
use Encode ();
use open 'OUT' => ':utf8';

my ($scen, $imgdir) = @ARGV;
$imgdir = '.' unless $imgdir;
die "Usage: $0 <$scen> [image-dir] < map.xml\n" unless $scen && -d $imgdir;

my $scenario = HTML::Entities::encode_entities($scen);
my @levelnames;
do {
  my $xml = XML::Simple::XMLin('-', 'KeyAttr' => [], 'ForceArray' => 1);
  die "Usage: $0 <$scen> [image-dir] < map.xml\n" unless $xml;
  my $entries = $xml->{'entry'};
  die "Usage: $0 <$scen> [image-dir] < map.xml\n" unless $entries;
  for my $levelnum (0..(scalar(@$entries)-1))
  {
    my $level = $entries->[$levelnum];
    my $infochunk = FindChunk($level, 'Minf');
    next unless $infochunk && $infochunk->[0];
    my $levelname = $infochunk->[0]{'content'} ||
                    '(Level ' . ($levelnum + 1) . ')';
    utf8::decode($levelname);
    push(@levelnames, HTML::Entities::encode_entities($levelname));
  }
};

my $indexfh;
open($indexfh, '>', 'index.html') or die;
print $indexfh <<END;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en"><head>
<title>$scenario Terminals</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<style type="text/css">
body {
  background: black;
  color: #0f0;
}
div {
  border: solid 1px #333;
  padding: 0;
  width: 640px;
  margin: 12px auto;
}
img {
  width: 640px;
  height: 320px;
}
a {
  color: #7bf !important;
}
</style>
</head>
<body>
<h1>$scenario Terminals</h1>
<ul>
END


for my $lev (0..scalar(@levelnames)-1)
{
  my $levfh;
  my $scr = 0;
  while (1)
  {
    my $prefix = $imgdir . '/' . $lev . '_s' . $scr;
    my $unfinished = $prefix . 'u_p0.png';
    my $has_un = -f $unfinished;
    my $success = $prefix . 's_p0.png';
    my $has_suc = -f $success;
    last unless ($has_un || $has_suc);
    my $has_both = $has_un && $has_suc;
    
    unless ($levfh)
    {
      my $htmlname = "lev$lev.html";
      open($levfh, '>', $htmlname) or die;
      print $indexfh <<END;
<li><a href="$htmlname">$levelnames[$lev]</a></li>
END
      print $levfh <<END;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en"><head>
<title>$scenario Terminals: $levelnames[$lev]</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<style type="text/css">
body {
  background: black;
  color: #0f0;
}
h1, h2, h3, h4 {
  text-align: center;
}
div {
  border: solid 2px #333;
  padding: 0;
  width: 640px;
  margin: 12px auto;
}
img {
  width: 640px;
  height: 320px;
}
</style>
</head>
<body>
<h1>$scenario Terminals: $levelnames[$lev]</h1>
END
    }
    for my $stat ([ $has_un,  'u', '1st' ],
                  [ $has_suc, 's', '2nd' ])
    {
      my ($present, $suffix, $msg) = @$stat;
      next unless $present;
      my $fix = $prefix . $suffix . '_p';
      
      my $anchor = 'lev' . $lev . '_t' . $scr;
      $anchor .= '_' . $suffix if $has_both;
      print $levfh <<END;
<h4 id="$anchor">$levelnames[$lev]
(Terminal $scr@{[ $has_both ? ": $msg message" : '' ]})</h4>
END
      my $pg = 0;
      while (1)
      {
        my $fname = $fix . $pg . '.png';
        last unless -e $fname;
        print $levfh <<END;
<div><img src="$fname"></div>
END
        $pg++;
      }
    }
    $scr++;
  }
  print $levfh <<END if $levfh;
</body></html>
END
}

print $indexfh <<END;
</ul>
</body></html>
END

exit;

sub FindChunk
{
  my ($level, $chunkname) = @_;
  
  for my $chunk (@{ $level->{'chunk'} })
  {
    if ($chunk->{'type'} eq $chunkname)
    {
      for my $key (keys %$chunk)
      {
        next if $key eq 'type';
        next if $key eq 'size';
        return $chunk->{$key};
      }
    }
  }
  return undef;
}
