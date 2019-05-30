# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::string;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache2::Const -compile => 'OK';

require TestAPRlib::string;

sub handler {
    my $r = shift;

    my $num_of_tests = TestAPRlib::string::num_of_tests();
    plan $r, tests => $num_of_tests;

    TestAPRlib::string::test();

    Apache2::Const::OK;
}

1;
__END__
