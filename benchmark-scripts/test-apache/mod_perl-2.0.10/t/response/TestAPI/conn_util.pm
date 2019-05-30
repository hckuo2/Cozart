# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::conn_util;

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::Connection ();

use Apache2::Const -compile => qw(OK REMOTE_HOST REMOTE_NAME
    REMOTE_NOLOOKUP REMOTE_DOUBLE_REV);

sub handler {
    my $r = shift;

    my $c = $r->connection;

    plan $r, tests => 7;

    ok $c->get_remote_host() || 1;

    for (Apache2::Const::REMOTE_HOST, Apache2::Const::REMOTE_NAME,
        Apache2::Const::REMOTE_NOLOOKUP, Apache2::Const::REMOTE_DOUBLE_REV) {
        ok $c->get_remote_host($_) || 1;
    }

    ok $c->get_remote_host(Apache2::Const::REMOTE_HOST,
                           $r->per_dir_config) || 1;
    ok $c->get_remote_host(Apache2::Const::REMOTE_HOST, $r->per_dir_config) || 1;

    Apache2::Const::OK;
}

1;
