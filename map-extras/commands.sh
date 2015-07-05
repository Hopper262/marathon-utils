#!/bin/sh

# extract data fork
./macbin2data.pl < Marathon/Map.scen > M1.map
./macbin2data.pl < "Marathon 2"/Map.sceA > M2.map
./macbin2data.pl < "Marathon Infinity"/Map.sceA > M3.map

# create XML
./wad2xml.pl < M1.map > M1.xml
./wad2xml.pl < M2.map > M2.xml
./wad2xml.pl < M3.map > M3.xml

# generate automap-style images
./mapxml2images.pl -dir M1 -ignore map-extras/M1_ignored_polys.txt -font map-extras/ProFontAO.ttf -html -scales < M1.xml
./mapxml2images.pl -dir M2 -ignore map-extras/M2_ignored_polys.txt -font map-extras/ProFontAO.ttf -html -scales < M2.xml
./mapxml2images.pl -dir M3 -ignore map-extras/M3_ignored_polys.txt -font map-extras/ProFontAO.ttf -html -scales < M3.xml

# generate editor-style images
./mapxml2images.pl -dir M1a -nozoom -all -html -margin 0 < M1.xml
./mapxml2images.pl -dir M2a -nozoom -all -html -margin 0 < M2.xml
./mapxml2images.pl -dir M3a -nozoom -all -html -margin 0 < M3.xml
