# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCompat::request_body;

# $r->"method" tests that are validated by the client

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test ();

use Apache2::compat ();
use Apache::Constants qw(OK M_POST DECLINED);

use subs qw(ok debug);
my $gr;

sub handler {
    my $r = shift;
    $gr = $r;

    $r->send_http_header('text/plain');

    my $cfg = Apache::Test::config();
    my $vars = $cfg->{vars};

    my %data;
    if ($r->method_number == M_POST) {
        %data = $r->content;
    }
    else {
        %data = $r->Apache::args;
    }

    return DECLINED unless exists $data{test};

    if ($data{test} eq 'content' || $data{test} eq 'args') {
        $r->print("test $data{test}");
    }
    elsif ($data{test} eq 'decoding') {
        $r->print(encode($data{body}));
    }
    elsif ($data{test} eq 'big_input') {
        $r->print(length $data{body});
    }
    else {
        # nothing
    }

    OK;
}

sub encode {
    my $val = shift;
    $val =~ s/(.)/sprintf "%%%02X", ord $1/eg;
    $val =~ s/\%20/+/g;
    return $val;
}


1;
__END__
PerlOptions +GlobalRequest
