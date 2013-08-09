m1defs
======

Perl scripts to read and convert Marathon 1 global data definitions into source code or MML, for use with Aleph One.

The global data block is 18806 bytes in length. Identified sections:

- 0-110: cheat codes
- 110-614: key definitions
- 614-788: [174 bytes: unknown]
- 788-916: [zeroes]
- 916-1248: date/time strings
- 1248-1310: [62 bytes: unknown sparse data]
- 1310-1412: [19 x 6-byte records: index, -1, unknown]
- 1412-1440: [zeroes]
- 1440-1484: [44 bytes: unknown]
- 1484-1850: [zeroes]
- 1850-1918: [68 bytes: unknown sparse data]
- 1918-2144: [zeroes]
- 2144-2194: [50 bytes: unknown]
- 2194-2228: [zeroes]
- 2228-2292: [16 x 4-byte records: sound, flags?]
- 2292-2340: [48 bytes: unknown]
- 2340-2814: [zeroes]
- 2814-3012: [serial number tables]
- 3012-3174: [9 x 18-byte records]
- 3174-3218: [zeroes]
- 3218-3812: fade defs
- 3812-3828: [zeroes, mostly]
- 3828-4234: weapon interface defs
- 4234-4454: [11 x 20-byte records]
- 4454-4468: [zeroes]
- 4468-4472: 640, 480
- 4472-4644: [zeroes]
- 4644-4868: terminal tags
- 4868-4940: [zeroes]
- 4940-4964: [6 x 4-byte records: -1, unknown; like 1310?]
- 4964-5012: [unknown - 0, 90, 60]
- 5012-5348: platform defs
- 5348-5576: wad tags
- 5576-7460: [zeroes, mostly]
- 7460-7672: overhead map info
- 7672-7704: [zeroes]
- 7704-7844: control panels and switches
- 7844-7846: [zeroes]
- 7846-13504: monster defs
- 13504-13536: [32 bytes: unknown]
- 13536-13610: player shape defs
- 13610-13634: [zeroes]
- 13634-14474: weapon defs
- 14474-14714: item defs
- 14714-14772: [58 bytes: unknown]
- 14772-14814: [7 x 6-byte records: colors?]
- 14814-15014: physics constants
- 15014-15018: [zeroes]
- 15018-15918: projectile defs
- 15918-15922: [zeroes]
- 15922-16150: effect defs
- 16150-16286: scenery defs
- 16286-16302: [16 bytes: unknown]
- 16302-16944: [zeroes, mostly]
- 16944-EOF: [generic library data?]


### *_defs.pl

These expect "m1.dat" on stdin, and generate C code on stdout. They generate the corresponding definition structures.

The scripts include the offset to the start of data. These were found through trial and error, by looking for data unchanged in M2. I also had to guess at the number of entries, but most of the time the following data was obviously wrong.

### *_defs_mml.pl

These expect "m1.dat" on stdin, and generate an MML file on stdout. Most of the M1-specific data can be overridden by MML instead of needing engine changes.

### m1.dat

This is binary data extracted from Marathon's CODE resources. Created with unpack\_mpw\_data.pl from my "classic-mac-utils" repository. I don't normally include data files, but this isn't easy to extract.

### io.subs, enum.subs, mml.subs

Support routines for the scripts.

### build_all.sh

Simple batch file to build everything.
