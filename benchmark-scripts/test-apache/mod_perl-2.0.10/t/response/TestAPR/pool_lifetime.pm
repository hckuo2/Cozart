# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::pool_lifetime;

# this test verifies that if the perl pool object exceeds the
# life-span of the underlying pool struct we don't get segfaults

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => 'OK';

my $pool;

sub handler {
    my $r = shift;

    $r->print("Pong");
    $pool = $r->pool;

    Apache2::Const::OK;
}

1;
