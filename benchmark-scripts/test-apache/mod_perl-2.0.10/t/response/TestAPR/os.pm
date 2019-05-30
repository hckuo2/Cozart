# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::os;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::MPM ();
use APR::OS ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    if (Apache2::MPM->is_threaded) {
        my $tid = APR::OS::current_thread_id();
        ok t_cmp($tid, $tid, "current thread id: $tid / pid: $$");
    }
    else {
        ok t_cmp($$, $$, "current process id");
    }

    Apache2::Const::OK;
}

1;
