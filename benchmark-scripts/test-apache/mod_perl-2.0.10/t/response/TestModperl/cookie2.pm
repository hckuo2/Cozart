# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::cookie2;

use strict;
use warnings FATAL => 'all';

use Apache::TestTrace;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => 'OK';

sub access {
    my $r = shift;

    $r->subprocess_env if $r->args eq 'subprocess_env';
    my ($key, $val) = cookie($r);
    die "I shouldn't get the cookie" if $r->args eq 'env' && defined $val;

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
    my $env    = $ENV{HTTP_COOKIE} || $ENV{COOKIE} || ''; # from CGI::cookie2
    debug "cookie (" .$r->args . "): header: [$header], env: [$env]";

    return split '=', $r->args eq 'header' ? $header : $env;
}

1;

__DATA__
SetHandler modperl
PerlModule          TestModperl::cookie2
PerlAccessHandler   TestModperl::cookie2::access
PerlResponseHandler TestModperl::cookie2
