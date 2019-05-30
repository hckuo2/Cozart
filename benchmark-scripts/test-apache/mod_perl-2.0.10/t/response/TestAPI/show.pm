# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::show;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::MPM ();
use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    my $mpm = Apache::Test::config->{server}->{mpm};

    ok t_cmp(Apache2::MPM->show(),
             qr!$mpm!i,
             'Apache2::MPM->show()');

    Apache2::Const::OK;
}

1;
