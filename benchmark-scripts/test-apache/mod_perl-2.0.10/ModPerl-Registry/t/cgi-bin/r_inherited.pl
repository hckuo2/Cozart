# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings;

# this script shouldn't work

# this is to test that $r is not in the scope from the function that
# has compiled this script in the registry module

# my $r = shift;

$r->content_type('text/plain');
$r->print($r->args);
