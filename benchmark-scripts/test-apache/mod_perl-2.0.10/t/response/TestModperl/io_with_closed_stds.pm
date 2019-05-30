# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::io_with_closed_stds;

# test that we can successfully override STD(IN|OUT) for
# 'perl-script', even if they are closed.

# in this test we can't use my $foo as a filehandle, since perl 5.6
# doesn't know how to dup via: 'open STDIN,  "<&", $oldin'
# so use the old FOO filehandle style, which is also global, so we
# don't even need to pass it around (very bad code style, but I see no
# better solution if we want to have this test run under perl 5.6)

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();

use Apache::Test;

use Apache2::Const -compile => 'OK';

sub fixup {
    my $r = shift;

    # we must close STDIN as well, due to a perl bug (5.8.0 - 5.8.3
    # w/useperlio), which emits a warning if dup is called with
    # one of the STD streams is closed.
    open OLDIN,  "<&STDIN"  or die "Can't dup STDIN: $!";
    open OLDOUT, ">&STDOUT" or die "Can't dup STDOUT: $!";
    close STDIN;
    close STDOUT;

    Apache2::Const::OK;
}

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    ok 1;

    Apache2::Const::OK;
}

sub cleanup {
    my $r = shift;

    # restore the STD(IN|OUT) streams so not to affect other tests.
    open STDIN,  "<&OLDIN"  or die "Can't dup OLDIN: $!";
    open STDOUT, ">&OLDOUT" or die "Can't dup OLDOUT: $!";
    close OLDIN;
    close OLDOUT;

    Apache2::Const::OK;
}

1;
__DATA__
PerlModule TestModperl::io_with_closed_stds
SetHandler perl-script
PerlFixupHandler    TestModperl::io_with_closed_stds::fixup
PerlResponseHandler TestModperl::io_with_closed_stds
PerlCleanupHandler  TestModperl::io_with_closed_stds::cleanup
