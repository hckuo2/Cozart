# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::perl;

# this test includes tests for buggy Perl functions for which mod_perl
# provides a workaround

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    ok t_cmp("SNXJvM5I.PJrE",
             crypt("testing", "SNXJvM5I.PJrE"),
             "crypt");

    Apache2::Const::OK;
}

1;
__END__


