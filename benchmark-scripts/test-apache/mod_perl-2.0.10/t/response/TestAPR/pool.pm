# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::pool;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache2::RequestRec ();
use APR::Pool ();
use APR::Table ();

use Apache2::Const -compile => 'OK';

use TestAPRlib::pool;

sub handler {
    my $r = shift;

    plan $r, tests => 4 + TestAPRlib::pool::num_of_tests();

    ### native pools ###

    # explicit destroy shouldn't destroy native pools
    {
        my $p = $r->pool;

        my $count = TestAPRlib::pool::ancestry_count($p);
        t_debug "\$r->pool has 2 or more ancestors (found $count)";
        ok $count >= 2;

        $p->cleanup_register(\&set_cleanup, [$r, 'native destroy']);

        $p->destroy;

        my @notes = $r->notes->get('cleanup');

        ok t_cmp(scalar(@notes), 0, "should be 0 notes");

        $r->notes->clear;
    }


    # implicit DESTROY shouldn't destroy native pools
    {
        {
            my $p = $r->pool;

            my $count = TestAPRlib::pool::ancestry_count($p);
            t_debug "\$r->pool has 2 or more ancestors (found $count)";
            ok $count >= 2;

            $p->cleanup_register(\&set_cleanup, [$r, 'native scoped']);
        }

        my @notes = $r->notes->get('cleanup');

        ok t_cmp(scalar(@notes), 0, "should be 0 notes");

        $r->notes->clear;
    }

    TestAPRlib::pool::test();

    Apache2::Const::OK;
}

sub set_cleanup {
    my $arg = shift;
    debug "setting cleanup note: $arg->[1]";
    $arg->[0]->notes->set(cleanup => $arg->[1]);
    1;
}


1;
