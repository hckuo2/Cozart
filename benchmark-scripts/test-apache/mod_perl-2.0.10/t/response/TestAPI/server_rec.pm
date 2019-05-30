# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::server_rec;

# this test module is only for testing fields in the server_rec listed
# in apache_structures.map

# XXX: This test needs to be mucho improved. currently it justs checks
# whether some value is set or not

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestRec ();
use Apache2::ServerRec ();
use Apache2::ServerUtil ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $s = $r->server;

    plan $r, tests => 20;

    ok $s;

    ok $s->process;

    ok $s->next || 1;

    ok $s->server_admin;

    ok $s->server_hostname;

    ok $s->port || 1;

    ok $s->error_fname || 1; # vhost might not have its own (t/TEST -ssl)

    # XXX: error_log;

    ok $s->loglevel;

    ok $s->is_virtual || 1;

    # XXX: module_config

    # XXX: lookup_defaults

    ok $s->addrs;

    t_debug("timeout : ", $s->timeout);
    ok $s->timeout;

    t_debug("keep_alive_timeout : ", $s->keep_alive_timeout);
    ok $s->keep_alive_timeout || 1;
    t_debug("keep_alive_max : ", $s->keep_alive_max);
    ok $s->keep_alive_max || 1;
    ok $s->keep_alive || 1;

    ok $s->path || 1;

    ok $s->names || 1;

    ok $s->wild_names || 1;

    ok $s->limit_req_line;

    ok $s->limit_req_fieldsize;

    ok $s->limit_req_fields;

    Apache2::Const::OK;
}

1;
