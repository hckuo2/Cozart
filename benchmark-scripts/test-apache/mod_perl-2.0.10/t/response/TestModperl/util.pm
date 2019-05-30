# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::util;

# Modperl::Util tests

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use ModPerl::Util ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    ok t_cmp ModPerl::Util::current_perl_id(), qr/0x\w+/,
        "perl interpreter id";

    Apache2::Const::OK;
}

1;
__END__
