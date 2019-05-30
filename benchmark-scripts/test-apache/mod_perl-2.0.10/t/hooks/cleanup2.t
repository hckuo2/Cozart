# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use File::Spec::Functions qw(catfile catdir);

use constant TRIES => 20;

my $vars = Apache::Test::config->{vars};
my $dir  = catdir $vars->{documentroot}, "hooks";
my $file = catfile $dir, "cleanup2";

plan tests => 2;

{
    # cleanup, just to make sure we start with virgin state
    if (-e $file) {
        unlink $file or die "Couldn't remove $file";
    }
    # this registers and performs cleanups, but we test whether the
    # cleanup was run only in the next sub-test
    my $location = "/TestHooks__cleanup2";
    my $expected = 'cleanup2 is ok';
    my $received = GET_BODY $location;
    ok t_cmp($received, $expected, "register req cleanup");
}

{
    # this sub-tests checks that the cleanup stage was run successfully
    # which is supposed to remove the file that was created
    #
    # since Apache destroys the request rec after the logging has been
    # finished, we have to give it some time  to get there
    # and remove in the file. (wait 0.25 .. 5 sec)
    my $t = 0;
    select undef, undef, undef, 0.25 until !-e $file || $t++ == TRIES;

    if (-e $file) {
        t_debug("$file wasn't removed by the cleanup phase");
        ok 0;
        unlink $file; # cleanup
    }
    else {
        ok 1;
    }
}



