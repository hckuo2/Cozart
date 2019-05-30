# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::status;

# see the client for details

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => 'OK';

my $body = "This is a response string";

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    my ($code, $string) = split /=/, $r->args || '';

    if ($string) {
        # status_line must be valid and match status
        # or it is 'zapped' by httpd as of 2.2.1
        $r->status($code);
        $r->status_line("$code $string");
    }
    else {
        $r->status($code);
    }

    Apache2::Const::OK;
}

1;
