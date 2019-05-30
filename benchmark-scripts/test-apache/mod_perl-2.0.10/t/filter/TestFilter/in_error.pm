# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_error;

# errors in filters should be properly propogated to httpd

# XXX: need to test output as well, and separately connection and
# request filters

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();
use APR::Table ();

use Apache::TestTrace;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);

sub handler {
    my $filter = shift;

    debug join '', "-" x 20 , " filter called ", "-" x 20;

    die "This filter must die";

    return Apache2::Const::OK;
}

sub response {
    my $r = shift;

    # cause taint problems, as there was a bug (panic: POPSTACK)
    # caused when APR/Error.pm was attempted to be loaded from
    # $r->read() when the latter was trying to croak about the failed
    # read, due to the filter returning 500
    eval { system('echo', 'hello') };

    t_server_log_error_is_expected(2);
    my $len = $r->read(my $data, $r->headers_in->{'Content-Length'});

    $r->content_type('text/plain');
    $r->print("it shouldn't be printed, because the input filter has died");

    Apache2::Const::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_error
PerlResponseHandler TestFilter::in_error::response
