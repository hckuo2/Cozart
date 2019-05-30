# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCompat::apache_table;

# Apache::Table compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache2::compat ();
use Apache::Constants qw(OK);

sub handler {
    my $r = shift;

    plan $r, tests => 2;

    $r->send_http_header('text/plain');

    my $t = Apache::Table->new($r);
    my $t_class = ref $t;

    ok t_cmp($t_class, 'APR::Table', "Apache::Table->new");

    ok t_cmp($r->is_main, !$r->main,
             '$r->is_main');

    OK;
}

1;

