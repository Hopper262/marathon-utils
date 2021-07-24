#!perl
use strict;
use warnings 'FATAL' => 'all';
use IO::Uncompress::Inflate qw(inflate $InflateError);

# CMT compression is a modified RFC 1950 deflate stream:
# - 4-byte header with uncompressed size, in big-endian format
# - 2-byte RFC 1950 header
# - compressed data blocks
# - no CRC32 at end
seek STDIN, 4, 1;
inflate '-' => '-' or die "inflate failed: $InflateError\n";
