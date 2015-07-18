marathon-utils/terminals
========================

These scripts format and display Marathon terminals.

### termxml2images.pl

Reads a map file in XML format, and produces a set of PNG, PDF, or SVG images displaying terminal information. Because terminals draw from a variety of sources, you will need:

* Map XML from map2xml.pl
* Terminal images in PNG format: convert Atque's exported images to PNG, or use extract_rsrc.pl and pict2png.pl from my "classic-mac-utils" repository
* A config file for color and stringset info (a default file is included here)
* Appropriate fonts (some are included here)

Pass "-help" for more information on the options.

### config.ph, config-pdf.ph

Two examples of the config data expected by termxml2images.pl.

### html_preview.pl

Generates a set of HTML files to navigate the terminal images. Use after termxml2images.pl. For example:

    ./termxml2images.pl -dir terminals < infinity.xml
    cd terminals
    ../html_preview.pl "Marathon Infinity" < infinity.xml
    open index.html
