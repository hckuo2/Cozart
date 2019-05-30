# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::read;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use TestCommon::Utils;

use Apache2::Const -compile => 'OK';

use constant BUFSIZ => 512; #small for testing

sub handler {
    my $r = shift;
    $r->content_type('text/plain');

    my $cl = $r->headers_in->get('content-length');
    my $buffer = "";
    my $bufsiz = $r->args || BUFSIZ;

    my $offset = 0;
    while (my $remain = $cl - $offset) {
        my $len = $remain >= $bufsiz ? $bufsiz : $remain;
        my $read = $r->read($buffer, $len, $offset);
        if ($read != $len) {
            die "read only ${read}b, while ${len}b were requested\n";
        }
        last unless $read > 0;
        $offset += $read;
    }

    die "read() has returned untainted data:"
        unless TestCommon::Utils::is_tainted($buffer);

    # make sure we dont block after all data is read
    my $n = $r->read(my $x, BUFSIZ);
    die unless $n == 0;

    $r->puts($buffer);

    Apache2::Const::OK;
}

1;
