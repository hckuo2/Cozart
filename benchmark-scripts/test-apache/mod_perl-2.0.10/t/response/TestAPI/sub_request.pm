# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::sub_request;

# basic subrequest tests

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK SERVER_ERROR);

my $uri = '/' . Apache::TestRequest::module2path(__PACKAGE__);

sub handler {
    my $r = shift;

    my $args = $r->args || '';
    return Apache2::Const::SERVER_ERROR if $args eq 'subreq';

    plan $r, tests => 4;

    my $subr = $r->lookup_uri("$uri?subreq");
    ok $subr->isa('Apache2::SubRequest');

    ok t_cmp $subr->uri, $uri, "uri";

    my $rc = $subr->run;
    ok t_cmp $rc, Apache2::Const::SERVER_ERROR, "rc";

    # test an explicit DESTROY (which happens automatically on the
    # scope exit)
    undef $subr;
    ok 1;

    Apache2::Const::OK;
}

1;
__DATA__

