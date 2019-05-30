# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::sendfile;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use APR::Const -compile => 'SUCCESS';
use Apache2::Const -compile => ':common';

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    my $args = $r->args;

    if ($args eq 'withwrapper') {
        # buffer output up, so we can test that sendfile flushes any
        # buffered output before sending the file contents out
        local $|;
        $r->print("This is a header\n");
        $r->sendfile(__FILE__);
        $r->print("This is a footer\n");
    }
    elsif ($args eq 'offset') {
        $r->sendfile(__FILE__, 3);
    }
    elsif ($args eq 'len') {
        $r->sendfile(__FILE__, 3, 50);
    }
    elsif ($args eq 'noexist-n-nocheck.txt') {
        eval { $r->sendfile($args) };
        return int $@;
    }
    else {
        my $rc = $r->sendfile($args);
        # warn APR::Error::strerror($rc);
        return $rc unless $rc == APR::Const::SUCCESS;
    }

    # XXX: can't quite test bogus offset and/or len, since ap_send_fd
    # doesn't provide any error indications

    return Apache2::Const::OK;
}

1;
