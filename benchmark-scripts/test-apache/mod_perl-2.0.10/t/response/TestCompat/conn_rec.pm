# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCompat::conn_rec;

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache2::compat ();

use Socket qw(sockaddr_in inet_ntoa);

use Apache::Constants qw(OK);

sub handler {

     my $r = shift;

     my $c = $r->connection;

     plan $r, tests => 4;

     Apache2::compat::override_mp2_api('Apache2::Connection::local_addr');
     my ($local_port, $local_addr) = sockaddr_in($c->local_addr);
     Apache2::compat::restore_mp2_api('Apache2::Connection::local_addr');
     t_debug inet_ntoa($local_addr) . " :$local_port";
     ok $local_port;
     ok inet_ntoa($local_addr);

     Apache2::compat::override_mp2_api('Apache2::Connection::remote_addr');
     my ($remote_port, $remote_addr) = sockaddr_in($c->remote_addr);
     Apache2::compat::restore_mp2_api('Apache2::Connection::remote_addr');
     t_debug inet_ntoa($remote_addr) . " :$remote_port";
     ok $remote_port;
     ok inet_ntoa($remote_addr);

     OK;
}

1;

