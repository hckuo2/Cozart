# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

local $| = 1; # unbuffered mode

my $r = shift;

print "Content-Type: text/html\n\n";
print "yet another boring test string";

# This line passes a bucket brigade with a single bucket FLUSH
# it was causing problems in the mod_deflate filter which was trying to
# deflate empty output buffer, (the previous print has already flushed
# all the output) (the fix in mod_deflate.c was to check whether the
# buffer is full)
print "";

