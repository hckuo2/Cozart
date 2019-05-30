# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::custom_response;

# custom_response() doesn't alter the response code, but is used to
# replace the standard response body

use strict;
use warnings FATAL => 'all';

use Apache2::Response ();

use Apache2::Const -compile => qw(FORBIDDEN);

sub handler {
    my $r = shift;

    my $how = $r->args || '';
    # warn "$how";
    # could be text or url
    $r->custom_response(Apache2::Const::FORBIDDEN, $how);

    return Apache2::Const::FORBIDDEN;
}

1;
__END__
<NoAutoConfig>
<Location /TestAPI__custom_response>
    AuthName dummy
    AuthType none
    PerlAccessHandler TestAPI::custom_response
</Location>
</NoAutoConfig>

