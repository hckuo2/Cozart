# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::cookie;

use strict;
use warnings FATAL => 'all';

use Apache::TestTrace;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => 'OK';

sub access {
    my $r = shift;

    # setup CGI variables early
    $r->subprocess_env() if $r->args eq 'env';

    my ($key, $val) = cookie($r);
    my $cookie_is_expected =
        ($r->args eq 'header' or $r->args eq 'env') ? 1 : 0;
    die "Can't get the cookie" if $cookie_is_expected && !defined $val;

    return Apache2::Const::OK;
}

sub handler {
    my $r = shift;

    my ($key, $val) = cookie($r);
    $r->print($val) if defined $val;

    return Apache2::Const::OK;
}

sub cookie {
    my $r = shift;

    my $header = $r->headers_in->{Cookie} || '';
    my $env    = $ENV{HTTP_COOKIE} || $ENV{COOKIE} || ''; # from CGI::Cookie
    debug "cookie (" .$r->args . "): header: [$header], env: [$env]";

    return split '=', $r->args eq 'header' ? $header : $env;
}

1;

__DATA__
SetHandler perl-script
PerlModule          TestModperl::cookie
PerlAccessHandler   TestModperl::cookie::access
PerlResponseHandler TestModperl::cookie
PerlOptions -SetupEnv
