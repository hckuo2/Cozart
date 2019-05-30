# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings;

my $r = shift;
$r->content_type('text/plain');
print "Oops, can't find the requested doc";
