# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::authen_basic;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::Access ();

use Apache2::Const -compile => qw(OK HTTP_UNAUTHORIZED SERVER_ERROR);
use constant APACHE24   => have_min_apache_version('2.4.0');

sub handler {
    my $r = shift;

    my ($rc, $sent_pw) = $r->get_basic_auth_pw;

    return $rc if $rc != Apache2::Const::OK;

    my $user = $r->user;

    # We don't have to check for valid-user in 2.4.0+. If there is bug
    # in require valid-user handling, it will result in failed test with
    # bad username/password.
    if (!APACHE24) {
        my $requirement = $r->requires->[0]->{requirement};
        return Apache2::Const::SERVER_ERROR unless $requirement eq 'valid-user';
    }

    unless ($user eq 'dougm' and $sent_pw eq 'foo') {
        $r->note_basic_auth_failure;
        return Apache2::Const::HTTP_UNAUTHORIZED;
    }

    Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
<Location /TestHooks__authen_basic>
    require valid-user
    AuthType Basic
    AuthName simple
    PerlAuthenHandler TestHooks::authen_basic
    PerlResponseHandler Apache::TestHandler::ok1
    SetHandler modperl
</Location>
</NoAutoConfig>
