package TestModperl::stdfd2;

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

    local *STDIN;
    open STDIN, '<', $INC{'TestModperl/stdfd2.pm'}
        or die "Cannot open $INC{'TestModperl/stdfd2.pm'}";
    scalar readline STDIN for(1..2);

    my $expected=$.;

    $r->lookup_uri($r->uri)->run;

    $r->print("1..1\n");
    $r->print(($.==$expected ? '' : 'not ').
              "ok 1 - \$.=$. expected $expected\n");

    return Apache2::Const::OK;
}

1;
__DATA__
PerlModule TestModperl::stdfd2
PerlFixupHandler    TestModperl::stdfd2::fixup
PerlResponseHandler TestModperl::stdfd2
