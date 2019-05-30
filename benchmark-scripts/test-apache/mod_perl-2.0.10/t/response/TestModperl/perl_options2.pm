# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::perl_options2;

# test whether PerlOptions None works

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::ServerUtil ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);

my @srv = qw(
    OpenLogs
    PostConfig
    ChildInit
    ChildExit

    PreConnection
    ProcessConnection

    InputFilter
    OutputFilter

    PostReadRequest
    Trans
    MapToStorage
    HeaderParser
    Access
    Authen
    Authz
    Type
    Fixup
    Log
    Cleanup
);

sub handler {
    my $r = shift;

    plan $r, tests => scalar @srv, skip_reason('PerlOptions None is broken');

    my $s = $r->server;

    ok t_cmp($s->is_perl_option_enabled($_), 0,
             "$_ is off under PerlOptions None") for @srv;

    ok t_cmp($s->is_perl_option_enabled('Response'), 1,
             "Response is off under PerlOptions None");

    return Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
<VirtualHost TestModperl::perl_options2>
    PerlOptions None +Response
    <Location /TestModperl__perl_options2>
        SetHandler modperl
        PerlResponseHandler TestModperl::perl_options2
    </Location>
</VirtualHost>
</NoAutoConfig>
