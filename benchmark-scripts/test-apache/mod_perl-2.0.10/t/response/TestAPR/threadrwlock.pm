# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::threadrwlock;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => 'OK';

use TestAPRlib::threadrwlock;

sub handler {
    my $r = shift;

    my $tests = TestAPRlib::threadrwlock::num_of_tests();
    plan $r, tests => $tests, need_threads;

    TestAPRlib::threadrwlock::test();

    Apache2::Const::OK;
}

1;
