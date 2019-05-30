# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::write;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => 'OK';

use constant BUFSIZ => 512; #small for testing

sub handler {
    my $r = shift;
    $r->content_type('text/plain');

    $r->write("1..2");
    $r->write("\n", 1);

    my $ok = "ok 1\n";
    $r->write($ok, 2);
    $r->write($ok, -1, 2);

    $ok = "not ok 2\n";
    $r->write($ok, 5, 4);

    Apache2::Const::OK;
}

1;
