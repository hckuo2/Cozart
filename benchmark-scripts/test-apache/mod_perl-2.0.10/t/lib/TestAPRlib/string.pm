# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPRlib::string;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::String ();

my %size_string = (
    '-1'            => "  - ",
    0               => "  0 ",
    42              => " 42 ",
    42_000          => " 41K",
    42_000_000      => " 40M",
#    42_000_000_000   => "40G",
);

sub num_of_tests {
    return scalar keys %size_string;
}

sub test {

    t_debug("size_string");
    while (my ($k, $v) = each %size_string) {
        ok t_cmp($v, APR::String::format_size($k));
    }
}

1;
