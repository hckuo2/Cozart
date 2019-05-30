# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCompat::conn_authen;

# compat checks for
#   $r->connection->auth_type
#   $r->connection->user
# both records don't exist in 2.0 conn_rec and therefore require
# 'PerlOptions +GlobalRequest' to retrieve those via Apache2::RequestUtil->request

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache2::compat ();
use Apache::Constants qw(OK REMOTE_HOST);

sub handler {

    my $r = shift;

    my $req_auth_type = $r->connection->auth_type || '';

    die "request auth_type is '$req_auth_type', should be empty"
        if $req_auth_type;

    # get_basic_auth_pw populates $r->user and $r->ap_auth_type
    my ($rc, $sent_pw) = $r->get_basic_auth_pw;

    return $rc if $rc != Apache2::Const::OK;

    $req_auth_type = $r->connection->auth_type || '';

    die "request auth_type is '$req_auth_type', should be 'Basic'"
        unless $req_auth_type eq 'Basic';

    my $config_auth_type = $r->auth_type || '';

    die "httpd.conf auth_type is '$config_auth_type', should be 'Basic'"
        unless $config_auth_type eq 'Basic';

    my $user = $r->connection->user || '';

    die "user is '$user', should be 'dougm'"
        unless $user eq 'dougm';

    # make sure we can set both
    $r->connection->auth_type('sailboat');
    $r->connection->user('geoff');

    $user = $r->connection->user || '';

    die "user is '$user', should be 'geoff'"
        unless $user eq 'geoff';

    $req_auth_type = $r->connection->auth_type || '';

    die "request auth_type is '$req_auth_type', should be 'sailboat'"
        unless $req_auth_type eq 'sailboat';

    OK;
}

1;

__DATA__
require valid-user
AuthType Basic
AuthName simple
SetHandler modperl
PerlOptions +GlobalRequest
PerlAuthenHandler TestCompat::conn_authen
PerlResponseHandler Apache::TestHandler::ok1

