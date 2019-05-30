# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::err_headers_out;

# tests: $r->err_headers_out

# when sending a non-2xx response one must use $r->err_headers_out to
# set extra headers

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use APR::Table ();

use Apache2::Const -compile => qw(OK NOT_FOUND);

sub handler {
    my $r = shift;

    # this header will always make it to the client
    $r->err_headers_out->add('X-err_headers_out' => "err_headers_out");

    # this header will make it to the client only on 2xx response
    $r->headers_out->add('X-headers_out' => "headers_out");

    return $r->args eq "404" ? Apache2::Const::NOT_FOUND : Apache2::Const::OK;
}

1;
__END__
