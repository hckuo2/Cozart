# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::access;

# demonstrates the phases execution (sometimes users claim that
# PerlInitHandler is running more than once
# run with:
# t/TEST -trace=debug -v hooks/access

use strict;
use warnings FATAL => 'all';

use APR::Table ();
use Apache2::Access ();
use Apache2::RequestRec ();
use Apache::TestTrace;

use Apache2::Const -compile => qw(OK FORBIDDEN);

my $allowed_ips = qr{^(10|127)\.};

sub handler {
    my $r = shift;

    my $fake_ip = $r->headers_in->get('X-Forwarded-For') || "";

    debug "access: " . ($fake_ip =~ $allowed_ips ? "OK\n" : "FORBIDDEN\n");

    return Apache2::Const::FORBIDDEN unless $fake_ip =~ $allowed_ips;

    Apache2::Const::OK;
}

sub fixup { debug "fixup\n"; Apache2::Const::OK }
sub init  { debug "init\n";  Apache2::Const::OK }

1;
__DATA__
<NoAutoConfig>
PerlModule TestHooks::access
<Location /TestHooks__access>
    PerlAccessHandler   TestHooks::access
    PerlInitHandler     TestHooks::access::init
    PerlFixupHandler    TestHooks::access::fixup
    PerlResponseHandler Apache::TestHandler::ok1
    SetHandler modperl
</Location>
#<Location />
#    PerlAccessHandler TestHooks::access
#</Location>
</NoAutoConfig>
