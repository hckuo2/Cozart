# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::query;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache2::MPM ();

use Apache2::Const -compile => qw(OK :mpmq);

sub handler {

    my $r = shift;

    plan $r, tests => 5;

    # ok, this isn't particularly pretty, but I can't think
    # of a better way to do it
    # all of these attributes I pulled right from the C sources
    # so if, say, leader all of a sudden changes its properties,
    # these tests will fail

    my $mpm = lc Apache2::MPM->show;

    if ($mpm eq 'prefork') {

        {
            my $query = Apache2::MPM->query(Apache2::Const::MPMQ_IS_THREADED);

            ok t_cmp($query,
                     Apache2::Const::MPMQ_NOT_SUPPORTED,
                     "MPMQ_IS_THREADED ($mpm)");

            # is_threaded() is just a constsub set to the result from
            # ap_mpm_query(AP_MPMQ_IS_THREADED)

            ok t_cmp($query,
                     Apache2::MPM->is_threaded,
                     "Apache2::MPM->is_threaded() equivalent to query(MPMQ_IS_THREADED)");

            t_debug('Apache2::MPM->is_threaded returned ' . Apache2::MPM->is_threaded);
            ok (! Apache2::MPM->is_threaded);
        }

        {
            my $query = Apache2::MPM->query(Apache2::Const::MPMQ_IS_FORKED);

            ok t_cmp($query,
                     Apache2::Const::MPMQ_DYNAMIC,
                     "MPMQ_IS_FORKED ($mpm)");
        }

    }
    elsif ($mpm eq 'worker') {

        {
            my $query = Apache2::MPM->query(Apache2::Const::MPMQ_IS_THREADED);

            ok t_cmp($query,
                     Apache2::Const::MPMQ_STATIC,
                     "MPMQ_IS_THREADED ($mpm)");

            ok t_cmp($query,
                     Apache2::MPM->is_threaded,
                     "Apache2::MPM->is_threaded() equivalent to query(MPMQ_IS_THREADED)");

            t_debug('Apache2::MPM->is_threaded returned ' . Apache2::MPM->is_threaded);
            ok (Apache2::MPM->is_threaded);
        }

        {
            my $query = Apache2::MPM->query(Apache2::Const::MPMQ_IS_FORKED);

            ok t_cmp($query,
                     Apache2::Const::MPMQ_DYNAMIC,
                     "MPMQ_IS_FORKED ($mpm)");
        }
    }
    elsif ($mpm eq 'leader') {

        {
            my $query = Apache2::MPM->query(Apache2::Const::MPMQ_IS_THREADED);

            ok t_cmp($query,
                     Apache2::Const::MPMQ_STATIC,
                     "MPMQ_IS_THREADED ($mpm)");

            ok t_cmp($query,
                     Apache2::MPM->is_threaded,
                     "Apache2::MPM->is_threaded() equivalent to query(MPMQ_IS_THREADED)");

            t_debug('Apache2::MPM->is_threaded returned ' . Apache2::MPM->is_threaded);
            ok (Apache2::MPM->is_threaded);
        }

        {
            my $query = Apache2::MPM->query(Apache2::Const::MPMQ_IS_FORKED);

            ok t_cmp($query,
                     Apache2::Const::MPMQ_DYNAMIC,
                     "MPMQ_IS_FORKED ($mpm)");
        }
    }
    elsif ($mpm eq 'winnt') {

        {
            my $query = Apache2::MPM->query(Apache2::Const::MPMQ_IS_THREADED);

            ok t_cmp($query,
                     Apache2::Const::MPMQ_STATIC,
                     "MPMQ_IS_THREADED ($mpm)");

            ok t_cmp($query,
                     Apache2::MPM->is_threaded,
                     "Apache2::MPM->is_threaded() equivalent to query(MPMQ_IS_THREADED)");

            t_debug('Apache2::MPM->is_threaded returned ' . Apache2::MPM->is_threaded);
            ok (Apache2::MPM->is_threaded);
        }

        {
            my $query = Apache2::MPM->query(Apache2::Const::MPMQ_IS_FORKED);

            ok t_cmp($query,
                     Apache2::Const::MPMQ_NOT_SUPPORTED,
                     "MPMQ_IS_FORKED ($mpm)");
        }
    }
    else {
        skip "skipping MPMQ_IS_THREADED test for $mpm MPM", 0;
        skip "skipping Apache2::MPM->is_threaded equivalence test for $mpm MPM", 0;
        skip "skipping MPMQ_IS_FORKED test for $mpm MPM", 0;
        skip "skipping Apache2::MPM->is_threaded test for $mpm MPM", 0;
    }

    # make sure that an undefined MPMQ constant yields undef
    {
        my $query = Apache2::MPM->query(72);

        ok t_cmp($query,
                 undef,
                 "unknown MPMQ value returns undef");
    }

    Apache2::Const::OK;
}

1;
