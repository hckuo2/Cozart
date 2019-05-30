# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::sockaddr;

# testing APR::SockAddr API

use strict;
use warnings  FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::Connection ();
use Apache2::RequestRec ();
use APR::SockAddr ();

use Apache2::Const -compile => 'OK';
use constant APACHE24   => have_min_apache_version('2.4.0');

sub handler {
    my $r = shift;
    my $c = $r->connection;

    plan $r, tests => 4;

    my $local  = $c->local_addr;
    my $remote = APACHE24 ? $c->client_addr : $c->remote_addr;

    ok t_cmp($local->ip_get,  $c->local_ip,  "local ip");
    if (APACHE24) {
        ok t_cmp($remote->ip_get, $c->client_ip, "client ip");
    }
    else {
        ok t_cmp($remote->ip_get, $c->remote_ip, "remote ip");
    }

    $r->subprocess_env;
    ok t_cmp($local->port,  $ENV{SERVER_PORT}, "local port");
    ok t_cmp($remote->port, $ENV{REMOTE_PORT}, "remote port");

    Apache2::Const::OK;
}

1;
