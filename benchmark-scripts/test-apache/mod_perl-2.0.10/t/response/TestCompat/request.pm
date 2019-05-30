# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCompat::request;

# $r->"method" compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use APR::Finfo ();

use File::Spec::Functions qw(catfile);

use Apache2::compat ();
use Apache::Constants qw(OK REMOTE_HOST);

sub handler {
    my $r = shift;

    plan $r, tests => 22;

    $r->send_http_header('text/plain');

    # header_in() and header_out() and err_header_out()
    for my $prefix ('err_', '') {
        my @ways = 'out';
        push @ways, 'in' unless $prefix;
        for my $way (@ways) {
            my $sub_test = "${prefix}header_$way";
            my $sub_good = "${prefix}headers_$way";
            my $key = 'header-test';

            # scalar context
            {
                my $key;
                if ($way eq 'in') {
                    $key = "user-agent"; # should exist with lwp
                } else {
                    # outgoing headers aren't set yet, so we set one
                    $key = "X-barabara";
                    $r->$sub_good->set($key, $key x 2);
                }

                ok t_cmp($r->$sub_test($key),
                         $r->$sub_good->get($key),
                         "\$r->$sub_test in scalar context");
            }

            # list context
            {
                my @exp = qw(foo bar);
                $r->$sub_good->add($key => $_) for @exp;
                ok t_cmp([ $r->$sub_test($key) ],
                         \@exp,
                         "\$r->$sub_test in list context");
            }

            # set
            {
                my $exp = $key x 2;
                $r->$sub_test($key => $exp);
                my $got = $r->$sub_test($key);
                ok t_cmp($got, $exp, "\$r->$sub_test set()");
            }

            # unset
            {
                my $exp = undef;
                $r->$sub_test($key => $exp);
                my $got = $r->$sub_test($key);
                ok t_cmp($got, $exp, "\$r->$sub_test unset()");
            }
        }
    }

    # $r->filename
    {
        Apache2::compat::override_mp2_api('Apache2::RequestRec::filename');
        my $orig = $r->filename;
        my $new  = catfile Apache::Test::vars("serverroot"),
            "conf", "httpd.conf";

        # in mp1 setting filename, updates $r's finfo (not in mp2)
        $r->filename($new);
        ok t_cmp $r->finfo->size, -s $new , "new filesize";

        # restore
        $new = __FILE__;
        $r->filename($new);
        ok t_cmp $r->finfo->size, -s $new , "new filesize";

        # restore the real 2.0 filename() method, now that we are done
        # with the compat one
        Apache2::compat::restore_mp2_api('Apache2::RequestRec::filename');
    }

    # $r->notes
    {
        Apache2::compat::override_mp2_api('Apache2::RequestRec::notes');

        my $key = 'notes-test';
        # get/set scalar context
        {
            my $val = 'ok';
            $r->notes($key => $val);
            ok t_cmp($val, $r->notes->get($key), "\$r->notes->get(\$key)");
            ok t_cmp($val, $r->notes($key),      "\$r->notes(\$key)");
        }

        # unset
        {
            my $exp = undef;
            $r->notes($key => $exp);
            my $got = $r->notes($key);
            ok t_cmp($got, $exp, "\$r->notes unset()");
        }

        # get/set list context
        {
            my @exp = qw(foo bar);
            $r->notes->add($key => $_) for @exp;
            ok t_cmp([ $r->notes($key) ], \@exp, "\$r->notes in list context");
        }

        # restore the real 2.0 notes() method, now that we are done
        # with the compat one
        Apache2::compat::restore_mp2_api('Apache2::RequestRec::notes');
    }

    # get_remote_host()
    ok $r->get_remote_host() || 1;
    ok $r->get_remote_host(Apache2::Const::REMOTE_HOST) || 1;

    # post_connection()
    $r->post_connection(sub { OK });
    ok 1;

    # register_cleanup
    ok 1;
    $r->register_cleanup(sub { OK });

    OK;
}

1;

