# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::setauth;

use strict;
use warnings FATAL => 'all';

use Apache2::Access ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 2;

     ok t_cmp($r->auth_type(), "none", 'auth_type');

    t_server_log_error_is_expected();
    $r->get_basic_auth_pw();

    ok t_cmp($r->auth_type(), 'Basic', 'default auth_type');

    Apache2::Const::OK;
}

1;
