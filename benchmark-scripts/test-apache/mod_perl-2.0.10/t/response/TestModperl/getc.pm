# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::getc;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestIO ();

use Apache::Test;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    untie *STDIN;
    tie *STDIN, $r;

    while (my $c = getc) {
        die "got more than 1 char" unless length($c) == 1;
        $r->puts($c);
    }

    untie *STDIN;

    Apache2::Const::OK;
}

1;
