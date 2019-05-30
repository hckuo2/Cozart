# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::authz;

use strict;
use warnings FATAL => 'all';

use Apache2::Access ();

use Apache2::Const -compile => qw(OK HTTP_UNAUTHORIZED);

sub auth_any {
    my $self = shift;
    my $r = shift;

    my ($res, $sent_pw) = $r->get_basic_auth_pw;
    return $res if $res != Apache2::Const::OK;

    unless($r->user and $sent_pw) {
        # testing $r->note_auth_failure:
        # AuthType Basic + note_auth_failure == note_basic_auth_failure;
        $r->note_auth_failure;
        return Apache2::Const::HTTP_UNAUTHORIZED;
    }

    return Apache2::Const::OK;
}

sub handler {
    my $r = shift;

    my $user = $r->user;

    return Apache2::Const::HTTP_UNAUTHORIZED unless $user;

    return Apache2::Const::HTTP_UNAUTHORIZED unless "dougm" eq $user;

    Apache2::Const::OK;
}

1;
__DATA__
require user dougm
AuthType Basic
AuthName simple
PerlModule          TestHooks::authz
PerlAuthenHandler   TestHooks::authz->auth_any
PerlResponseHandler Apache::TestHandler::ok1
SetHandler modperl
