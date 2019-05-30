# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use File::Spec::Functions qw(catfile catdir);

use constant SIZE  => 10;
use constant TRIES => 20;

my $file = catfile Apache::Test::vars("documentroot"), "hooks", "cleanup";

plan tests => 2;

{
    # this registers and performs cleanups, but we test whether the
    # cleanup was run only in the next sub-test
    my $location = "/TestHooks__cleanup";
    my $expected = 'ok';
    my $received = GET_BODY $location;
    ok t_cmp($received, $expected, "register req cleanup");
}

{
    # this sub-tests checks that the cleanup stage was run successfully

    # since Apache destroys the request rec after the logging has been
    # finished, we have to give it some time  to get there
    # and fill in the file. (wait 0.25 .. 5 sec)
    my $t = 0;
    select undef, undef, undef, 0.25
        until -e $file && -s _ == SIZE || $t++ == TRIES;

    unless (-e $file) {
        t_debug("can't find $file");
        ok 0;
    }
    else {
        open my $fh, $file or die "Can't open $file: $!";
        my $received = <$fh> || '';
        close $fh;
        my $expected = "cleanup ok";
        ok t_cmp($received, $expected, "verify req cleanup execution");

        # XXX: while Apache::TestUtil fails to cleanup by itself
        unlink $file;
    }

}



