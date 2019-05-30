# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCompat::send_fd;

use strict;
use warnings FATAL => 'all';

use Apache2::compat ();
use Apache2::RequestRec ();

use Apache2::Const -compile => ':common';

sub handler {
    my $r = shift;

    my $file = $r->args || __FILE__;

    open my $fh, $file or return Apache2::Const::NOT_FOUND;

    my $bytes = $r->send_fd($fh);

    return Apache2::Const::SERVER_ERROR unless $bytes == -s $file;

    Apache2::Const::OK;
}

1;
