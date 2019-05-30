# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::authen_digest;

use strict;
use warnings FATAL => 'all';

use Apache2::Access ();
use Apache2::RequestRec ();

use Apache2::Const -compile => qw(OK HTTP_UNAUTHORIZED);

sub handler {

    my $r = shift;

    # we don't need to do the entire Digest auth round
    # trip just to see if note_digest_auth_failure is
    # functioning properly - see authen_digest.t for the
    # header checks
    if ($r->args) {
        $r->note_digest_auth_failure;
        return Apache2::Const::HTTP_UNAUTHORIZED;
    }

    $r->user("user");
    $r->ap_auth_type("Digest");

    return Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
<Location /TestHooks__authen_digest>
    PerlAuthenHandler TestHooks::authen_digest
    PerlResponseHandler Apache::TestHandler::ok
    SetHandler modperl

    require valid-user
    AuthType Digest
    AuthName "Simple Digest"
</Location>
</NoAutoConfig>
