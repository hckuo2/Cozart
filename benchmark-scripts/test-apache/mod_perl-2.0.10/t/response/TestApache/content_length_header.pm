# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::content_length_header;

# see the client t/apache/content_length_header.t for the comments

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Response ();

use Apache2::Const -compile => 'OK';

my $body = "This is a response string";

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    my $args = $r->args || '';

    if ($args =~ /set_content_length/) {
        $r->set_content_length(length $body);
    }

    if ($args =~ /send_body/) {
        $r->print($body);
    }

    if ($args =~ /head_no_body/) {
        if ($r->header_only) {
            # see #2 in the discussion in the client
            $r->rflush;
        }
    }

    Apache2::Const::OK;
}

1;
