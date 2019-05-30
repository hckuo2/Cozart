# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::print;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestIO ();

use Apache::Test;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 6;

    binmode STDOUT; #Apache2::RequestRec::BINMODE (noop)

    ok 1;

    ok 2;

    {
        # print should return true on success, even
        # if it sends no data.
        my $rc = print '';

        ok ($rc);
        ok ($rc == 0);  # 0E0 is still numerically 0
    }

    {
        my $rc = print "# 11 bytes\n";  # don't forget the newline

        ok ($rc == 11);
    }

    printf "ok %d\n", 6;

    Apache2::Const::OK;
}

END {
    my $package = __PACKAGE__;
    warn "END in $package, pid=$$\n";
}

1;
