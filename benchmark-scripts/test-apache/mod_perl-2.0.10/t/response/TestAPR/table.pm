# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::table;

# testing APR::Table API

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache2::Const -compile => 'OK';

use TestAPRlib::table;

sub handler {
    my $r = shift;

    my $tests = TestAPRlib::table::num_of_tests();
    plan $r, tests => $tests;

    TestAPRlib::table::test();

    Apache2::Const::OK;
}

1;
