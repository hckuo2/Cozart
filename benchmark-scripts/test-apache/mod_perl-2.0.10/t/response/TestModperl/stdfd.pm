package TestModperl::stdfd;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();

use Apache2::Const -compile => 'OK';

sub fixup {
    my $r = shift;

    $r->handler($r->main ? 'perl-script' : 'modperl');
    return Apache2::Const::OK;
}

sub handler {
    my $r = shift;

    return Apache2::Const::OK if $r->main;

    my @fds=(fileno(STDIN), fileno(STDOUT));

    $r->lookup_uri($r->uri)->run;

    $r->print("1..2\n");
    $r->print((fileno(STDIN)==$fds[0] ? '' : 'not ').
              "ok 1 - fileno(STDIN)=".fileno(STDIN)." expected $fds[0]\n");
    $r->print((fileno(STDOUT)==$fds[1] ? '' : 'not ').
              "ok 2 - fileno(STDOUT)=".fileno(STDOUT)." expected $fds[1]\n");

    return Apache2::Const::OK;
}

1;
__DATA__
PerlModule TestModperl::stdfd
PerlFixupHandler    TestModperl::stdfd::fixup
PerlResponseHandler TestModperl::stdfd
