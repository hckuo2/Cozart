# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::io_nested_with_closed_stds;

# test that we can successfully override STD(IN|OUT) for
# 'perl-script', even if they are closed. Here we use
# internal_redirect(), which causes a nested override of already
# overriden STD streams

# in this test we can't use my $foo as a filehandle, since perl 5.6
# doesn't know how to dup via: 'open STDIN,  "<&", $oldin'
# so use the old FOO filehandle style

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $args = $r->args || '';
    if ($args eq 'redirect') {
        # sub-req
        $r->content_type('text/plain');
        # do not use plan() here, since it messes up with STDOUT,
        # which affects this test.
        print "1..1\nok 1\n";
    }
    else {
        # main-req
        my $redirect_uri = $r->uri . "?redirect";

        # we must close STDIN as well, due to a perl bug (5.8.0 - 5.8.3
        # w/useperlio), which emits a warning if dup is called with
        # one of the STD streams is closed.
        # but we must restore the STD streams so not to affect other
        # tests.
        open OLDIN,  "<&STDIN"  or die "Can't dup STDIN: $!";
        open OLDOUT, ">&STDOUT" or die "Can't dup STDOUT: $!";
        close STDIN;
        close STDOUT;

        $r->internal_redirect($redirect_uri);

        open STDIN,  "<&OLDIN"  or die "Can't dup OLDIN: $!";
        open STDOUT, ">&OLDOUT" or die "Can't dup OLDOUT: $!";
        close OLDIN;
        close OLDOUT;
    }

    Apache2::Const::OK;
}

1;
__DATA__
SetHandler perl-script

