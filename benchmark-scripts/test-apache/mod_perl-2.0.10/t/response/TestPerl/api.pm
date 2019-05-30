# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestPerl::api;

# some perl APIs that we need to test that they work alright under mod_perl

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache2::Build;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    # - XXX: with perl 5.6.1 this test works fine on its own, but if
    # run in the same interpreter after a test that involves a complex die
    # call, as in the case of t/filter/in_error, which dies inside a
    # filter, perl gets messed up here. this can be reproduced by
    # running:
    # t/TEST -maxclients 1 t/filter/in_error.t t/perl/api.t
    # so skip that test for now on 5.6
    #
    # - win32 is an unrelated issue
    plan $r, tests => 2,
        need { "getppid() is not implemented on Win32"
                   => !Apache2::Build::WIN32(),
               "getppid() is having problems with perl 5.6"
                   => !($] < 5.008),
               };

    {
        # 5.8.1 w/ ithreads has a bug where it caches ppid in PL_ppid,
        # but updates the record only if perl's fork is called, which
        # is not the case with mod_perl. This results in getppid()
        # returning 1. A local workaround in the mod_perl source at
        # the child_init phase fixes the problem.
        my $ppid = getppid();
        t_debug "ppid $ppid";
        ok $ppid > 1;

        # verify that $pid != $ppid
        t_debug "pid $$";
        ok $ppid != $$;
    }

    Apache2::Const::OK;
}

1;
