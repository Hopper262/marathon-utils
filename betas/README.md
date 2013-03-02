betas
=====

These scripts are specific to the Marathon 1 pre-releases. The early Marathon builds have features in common with Pathways Into Darkness; you might be interested in my "pathways-utils" repository to study the evolution of Bungie's data formats.

### alphashapes2xml.pl

Converts a binary Shapes file from the [Marathon Alpha](http://marathon.bungie.org/story/betasfjan94.html) shown in January 1994. The resulting XML is compatible with xml2shapes.pl in the parent directory.

### alphamap2images.pl

The alpha used a rudimentary map format with a fixed array of coded grid cells; this is quite common in games, but not in Bungie's. Combined with images like those in "alpha-mapcells", this script will produce a set of maps from the alpha data. The second level has a bunch of rooms inaccessible from the starting location.

### janshapes2xml.pl, mayshapes2xml.pl, juneshapes2xml.pl

The Marathon Trilogy release included three Marathon betas from early 1995. These scripts parse the three different formats. The resulting XML is compatible with xml2shapes.pl in the parent directory.
