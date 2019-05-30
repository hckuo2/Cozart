# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::push_handlers_blessed;

# test that we
# - can push and execute blessed anon handlers

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK DECLINED);

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    my $sub = sub {
        ok 1;

        return Apache2::Const::OK;
    };

    my $handler = bless $sub, __PACKAGE__;

    $r->push_handlers(PerlResponseHandler => $handler);

    return Apache2::Const::DECLINED;
}

1;
__DATA__
<NoAutoConfig>
<Location /TestHooks__push_handlers_blessed>
    SetHandler modperl
    PerlResponseHandler TestHooks::push_handlers_blessed
</Location>
</NoAutoConfig>
