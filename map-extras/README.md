marathon-utils/map-extras
=========================

These files can be used in conjunction with mapxml2images.pl to replicate the level images shown at [lhowon.org](https://www.lhowon.org/).

### mapxml2ignores.pl

This script detects potentially unreachable polygons and outputs a text file for use with the "-ignore" parameter. The finished maps thus look closer to a "fully completed" automap without showing unreachable areas. Note: Lua can move the player to such areas without this script noticing, so check the output carefully if Lua is involved.

### M1_ignored_polys.txt, M2_ignored_polys.txt, M3_ignored_polys.txt

These hand-edited files suppress polygons not automatically detected by the above script.

### mapxml2info.pl

This script outputs some summary statistics about each level in the map, including number of polygons and a simple reachable-area calculation.

### ProFontAO.ttf

This font is used for map annotations within Aleph One itself.

### commands.sh

Gives examples of the process and options used at lhowon.org. Will almost certainly fail if you run it as-is.
