# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::response;

# testing Apache2::Response methods
#
# XXX: a proper test is needed (at the moment just test that methods
# can be invoked as documented)

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::Response ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 7;

    my $etag = $r->make_etag();
    t_debug $etag;
    ok $etag;

    $r->set_content_length(0);

    ok 1;

    ok $r->meets_conditions || 1;

    ok $r->rationalize_mtime(time) >= $r->request_time;

    my $mtime = (stat __FILE__)[9];

    $r->update_mtime($mtime);

    ok $r->mtime == $mtime;

    ok $r->set_keepalive() || 1;

    $r->set_last_modified;

    # $r->custom_response() is tested in TestAPI::custom_response

    ok 1;

    Apache2::Const::OK;
}

1;
