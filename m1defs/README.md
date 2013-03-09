m1defs
======

Perl scripts to read and convert Marathon 1 global data definitions into source code for use with Aleph One.

### *_defs.pl

These expect "m1.dat" on stdin, and generate C code on stdout. They generate the corresponding definition structures.

The scripts include the offset to the start of data. These were found through trial and error, by looking for data unchanged in M2. I also had to guess at the number of entries, but most of the time the following data was obviously wrong.

### m1.dat

This is binary data extracted from Marathon's CODE resources. Created with unpack\_mpw\_data.pl from my "classic-mac-utils" repository. I don't normally include data files, but this isn't easy to extract.

### io.subs, enum.subs

Support routines for the scripts.

### build_all.sh

Simple batch file to build everything.
