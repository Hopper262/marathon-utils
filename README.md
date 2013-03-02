marathon-utils
==============

Perl scripts to read and write Marathon / Aleph One Shapes and other data files. These generally use XML as an intermediate format, to easily inspect the binary data and to separate file parsing from transformation tasks.

These are all command-line tools. Usually the input is expected on stdin and output is written to stdout.

### shapes2xml.pl, xml2shapes.pl

Converts a binary Shapes file in Marathon 2/Infinity format into an XML file, and vice versa. Also supports Prime Target, which used more than the standard number of collections.

### m1shapes2xml.pl

Converts a Marathon 1 Shapes resource fork to the same XML format as the above. Can be used to convert Marathon 1 shapes to Marathon 2 format, for use in ShapeFusion or Aleph One.

### prevshapes2xml.pl

Converts Marathon 2 Preview Shapes to XML. The Marathon 2 Preview used a file format halfway along the evolution from Marathon's format to the final Marathon 2; it was fun to reverse engineer.

### shapesxml2images.pl

Uses Image::Magick to produce images from a Shapes XML file. Creates animated GIFs from sequences

### patch2xml.pl, xml2patch.pl

Conversion for Anvil-format Shapes patches, which can also be used in Aleph One plugins. [ShapeFusion](http://shapefusion.sourceforge.net/) can be used to create patches. These scripts are good for verifying that your patches contain everything they're supposed to, and nothing they shouldn't.

### applypatch.pl

Applies an Anvil Shapes patch to a Shapes file. ShapeFusion can also do this.

