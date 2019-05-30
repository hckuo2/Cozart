# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::lookup_uri2;

use strict;
use warnings FATAL => 'all';

use Apache2::SubRequest ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();

use Apache2::Const -compile => 'OK';

sub myplan {
    my $r = shift;

    $r->puts("1..3\nok 1\n");

    die "must indicate a sub-request" if $r->is_initial_req();

    Apache2::Const::OK;
}

sub ok3 {
    my $r = shift;

    $r->puts("ok 3\n");

    Apache2::Const::OK;
}

sub subrequest {
    my ($r, $sub) = @_;
    (my $uri = join '::', __PACKAGE__, $sub) =~ s!::!__!g;
    $r->lookup_uri($uri)->run;
}

sub handler {
    my $r = shift;

    subrequest($r, 'myplan');

    $r->puts("ok 2\n");

    subrequest($r, 'ok3');

    Apache2::Const::OK;
}

1;
__DATA__
<Location /TestAPI__lookup_uri2__myplan>
    SetHandler modperl
    PerlResponseHandler TestAPI::lookup_uri2::myplan
</Location>

<Location /TestAPI__lookup_uri2__ok3>
    SetHandler modperl
    PerlResponseHandler TestAPI::lookup_uri2::ok3
</Location>
