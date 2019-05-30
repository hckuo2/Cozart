# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::internal_redirect_handler;

# $r->internal_redirect_handler() is the same as
# $r->internal_redirect() but it uses the same content-type as the
# top-level handler

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();

use Apache2::Const -compile => 'OK';

my $uri = '/' . Apache::TestRequest::module2path(__PACKAGE__);

sub handler {
    my $r = shift;

    my %args = map { split '=', $_, 2 } split /[&]/, $r->args;
    if ($args{main}) {
        # sub-req should see the same content-type as the top-level
        my $ct = $r->content_type;
        $r->content_type('text/plain');
        $r->print($ct);
    }
    else {
        # main-req
        $r->content_type($args{ct});
        $r->internal_redirect_handler("$uri?main=1");
    }

    Apache2::Const::OK;
}

1;
__DATA__
