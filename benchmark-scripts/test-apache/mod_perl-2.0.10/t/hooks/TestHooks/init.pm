# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::init;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::Table ();
use Apache2::RequestRec ();

use Apache2::Const -compile => qw(OK DECLINED);

sub first {
    my $r = shift;

    $r->notes->set(ok1 => 1);

    Apache2::Const::OK;
}

sub second {
    my $r = shift;

    my $ok = $r->notes->get('ok1') || 0;

    $r->notes->set(ok2 => $ok + 1);

    Apache2::Const::OK;
}

sub handler {
    my $r = shift;

    my $ok = $r->notes->get('ok2') || 0;

    $r->notes->set(ok3 => $ok + 1);

    Apache2::Const::DECLINED;
}

sub response {
    my $r = shift;

    my $tests = 3;
    plan $r, tests => $tests;

    for my $x (1..$tests) {
        my $val = $r->notes->get("ok$x") || 0;
        ok $val == $x;
    }

    Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
  <VirtualHost TestHooks::init>
    PerlModule      TestHooks::init
    PerlInitHandler TestHooks::init::first
    <Location /TestHooks__init>
        PerlInitHandler TestHooks::init::second
        PerlResponseHandler TestHooks::init
        PerlResponseHandler TestHooks::init::response
        SetHandler modperl
    </Location>
  </VirtualHost>
</NoAutoConfig>
