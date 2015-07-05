marathon-utils
==============

Perl scripts to read and write Marathon / Aleph One Shapes and other data files. These generally use XML as an intermediate format, to easily inspect the binary data and to separate file parsing from transformation tasks.

These are all command-line tools. Usually the input is expected on stdin and output is written to stdout. If you're starting from MacBinary-encoded files, see my "classic-mac-utils" repository for scripts and instructions.

### shapes2xml.pl, xml2shapes.pl

Converts a binary Shapes file in Marathon 2/Infinity format into an XML file, and vice versa. Also supports Prime Target, which used more than the standard number of collections.

### m1shapes2xml.pl

Converts a Marathon 1 Shapes resource fork to the same XML format as the above. Can be used to convert Marathon 1 shapes to Marathon 2 format, for use in ShapeFusion or Aleph One.

### prevshapes2xml.pl

Converts Marathon 2 Preview Shapes to XML. The Marathon 2 Preview used a file format halfway along the evolution from Marathon's format to the final Marathon 2; it was fun to reverse engineer.

### shapesxml2images.pl

Uses Image::Magick to produce images from a Shapes XML file. Creates animated GIFs from sequences.

### shapesxml2marine.pl

Written for the [Samsara](http://forum.zdoom.org/viewtopic.php?f=19&t=33219) Doom mod, this generates every combination of the player torso and leg sprites as a GIF, with a consistent frame size and origin. It builds nearly 23,000 images from the Infinity shapes.

### patch2xml.pl, xml2patch.pl

Conversion for Anvil-format Shapes patches, which can also be used in Aleph One plugins. [ShapeFusion](http://shapefusion.sourceforge.net/) can be used to create patches. These scripts are good for verifying that your patches contain everything they're supposed to, and nothing they shouldn't.

### applypatch.pl

Applies an Anvil Shapes patch to a Shapes file. ShapeFusion can also do this.

### strings2xml.pl

Converts 'STR ' and 'STR#' resources into a format suitable for pasting into Aleph One MML. Good for repackaging Marathon TCs. Also good for inspecting any classic Mac string resources.

### rsrc2mml.pl

Converts 'nrct', 'clut', 'finf', and 'STR#' resources from a Marathon-series application's resource fork into a format suitable for pasting into Aleph One MML. Even better than the above for repackaging Marathon TCs.

### wad2dir.pl

Extracts each chunk of a Marathon wad file, for easier inspection of the raw data. Like Atque, without any of the smart bits. This handles Marathon 1 and 2 formats, but will not accept MacBinary-encoded files.

### map2xml.pl

Converts Marathon maps or saved games to XML. This is a work in progress; only the geometry and a few other structures are exported. The script can also be used to do some basic inspection of other wad files. This handles Marathon 1 and 2 formats, but will not accept MacBinary-encoded files.

### mapxml2images.pl

Converts map XML (from map2xml.pl) into images similar to the in-game automap. Uses Cairo as the rendering engine to output PNG, PDF, or SVG files. Call with the "-help" option for more information.

