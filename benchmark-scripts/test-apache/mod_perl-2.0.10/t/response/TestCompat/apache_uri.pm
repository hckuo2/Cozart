# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCompat::apache_uri;

# Apache::Util compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache2::compat ();
use Apache::Constants qw(OK);

sub handler {
    my $r = shift;

    plan $r, tests => 19;

    {
        # XXX: rpath is not implemented and not in compat
        my @methods = qw(scheme hostinfo user password hostname path
                         query fragment port);
        my $test_uri = 'http://foo:bar@perl.apache.org:80/docs?args#frag';

        # Apache2::URI->parse internally returns an object blessed into
        # APR::URI and all the methods are called on that object
        for my $uri ($r->parsed_uri, Apache2::URI->parse($r, $test_uri)) {
            t_debug("URI=" . $uri->unparse);
            no strict 'refs';
            # just check that methods are call-able, the actual
            # testing happens in TestAPR::uri test
            for my $meth (@methods) {
                my $val = $uri->$meth();
                t_debug("$meth: " . ($val||''));
                ok $val || 1;
            }
        }
    }

    {
        Apache2::compat::override_mp2_api('APR::URI::unparse');
        # test the segfault in apr < 0.9.2 (fixed on mod_perl side)
        # passing only the /path
        my $parsed = $r->parsed_uri;
        # set hostname, but not the scheme
        $parsed->hostname($r->get_server_name);
        $parsed->port($r->get_server_port);
        #$parsed->scheme('http'); # compat defaults to 'http' like apache-1.3 did
        ok t_cmp($parsed->unparse, $r->construct_url);
        Apache2::compat::restore_mp2_api('APR::URI::unparse');
    }

    OK;
}

1;
