# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::headerparser;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::Table ();
use Apache2::RequestRec ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->notes->set(headerparser => 'set');

    Apache2::Const::OK;
}

sub response {
    my $r = shift;

    plan $r, tests => 1;

    ok $r->notes->get('headerparser') eq 'set';

    Apache2::Const::OK;
}

1;
__DATA__
PerlOptions +SetupEnv
PerlResponseHandler TestHooks::headerparser::response
SetHandler modperl
