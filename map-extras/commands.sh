#!/bin/sh

# extract data fork
./macbin2data.pl < Marathon/Map.scen > M1.map
./macbin2data.pl < "Marathon 2"/Map.sceA > M2.map
./macbin2data.pl < "Marathon Infinity"/Map.sceA > M3.map

# create XML
./map2xml.pl < M1.map > M1.xml
./map2xml.pl < M2.map > M2.xml
./map2xml.pl < M3.map > M3.xml

# generate automap-style images with markers
./mapxml2images.pl -dir M1o -ignore map-extras/M1_ignored_polys.txt -font map-extras/ProFontAO.ttf -zoom -html -scales -mark -legend < M1.xml
./mapxml2images.pl -dir M2o -ignore map-extras/M2_ignored_polys.txt -font map-extras/ProFontAO.ttf -zoom -html -scales -mark -legend < M2.xml
./mapxml2images.pl -dir M3o -ignore map-extras/M3_ignored_polys.txt -font map-extras/ProFontAO.ttf -zoom -html -scales -mark -legend < M3.xml

# generate editor-style images with gridlines
./mapxml2images.pl -dir M1g -all -html -margin 0 -grid < M1.xml
./mapxml2images.pl -dir M2g -all -html -margin 0 -grid < M2.xml
./mapxml2images.pl -dir M3g -all -html -margin 0 -grid < M3.xml
