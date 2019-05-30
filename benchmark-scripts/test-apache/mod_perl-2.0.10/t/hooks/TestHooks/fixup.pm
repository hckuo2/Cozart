# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::fixup;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::Table ();
use Apache2::RequestRec ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->notes->set(ok => 1);

    Apache2::Const::OK;
}

sub response {
    my $r = shift;

    plan $r, tests => 1;

    ok $r->notes->get('ok');

    Apache2::Const::OK;
}

1;
__DATA__
PerlResponseHandler TestHooks::fixup::response
SetHandler modperl
