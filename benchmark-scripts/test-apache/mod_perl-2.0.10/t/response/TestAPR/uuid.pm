# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::uuid;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use TestAPRlib::uuid;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => TestAPRlib::uuid::num_of_tests();

    TestAPRlib::uuid::test();

    Apache2::Const::OK;
}

1;
