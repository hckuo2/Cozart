# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::finfo;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use TestAPRlib::finfo;

use APR::Finfo ();

use Apache2::Const -compile => 'OK';
use APR::Const    -compile => qw(FINFO_NORM);

sub handler {
    my $r = shift;

    my $tests = 1 + TestAPRlib::finfo::num_of_tests();
    plan $r, tests => $tests;

    {
        my $finfo = $r->finfo;
        my $isa = $finfo->isa('APR::Finfo');

        t_debug "\$r->finfo $finfo";
        ok $isa;
    }

    # a test assigning to $r->finfo is in TestAPI::request_rec

    TestAPRlib::finfo::test();

    Apache2::Const::OK;
}

1;
