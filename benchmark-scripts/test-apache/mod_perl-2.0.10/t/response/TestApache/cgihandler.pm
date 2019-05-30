# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::cgihandler;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use APR::Table ();

use Apache2::Const -compile => qw(OK M_POST);

#test the 1.x style perl-script handler

sub handler {
    my $r = shift;

    $ENV{FOO} = 2;

    if ($r->method_number == Apache2::Const::M_POST) {
        my $cl = $r->headers_in->get('content-length');
        my $buff;
#XXX: working around a bug in ithreads Perl
#that would cause modules/cgi #3 to fail
#        read STDIN, $buff, $cl;
        read 'STDIN', $buff, $cl;
        print $buff;
    }
    else {
        print "1..3\n";
        print "ok 1\n", "ok ", "$ENV{FOO}\n";
#XXX: current implementation of tie %ENV to $r->subprocess_env
#     is not threadsafe
#        my $foo = $r->subprocess_env->get('FOO');
        my $foo = $ENV{FOO};
        $foo++;
        print "ok $foo\n";
    }

    Apache2::Const::OK;
}

1;
__END__
SetHandler perl-script
PerlResponseHandler TestApache::cgihandler

