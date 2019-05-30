# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $url = "/TestDirective__perlloadmodule2";

plan tests => 3;

{
    my $location = "$url?srv";
    my $expected = "srv: one two";
    my $received = GET_BODY $location;
    ok t_cmp($received, $expected, "access server settings");
}

{
    my $location = "$url?";
    my $expected = "dir: one two three four";
    my $received = GET_BODY $location;
    ok t_cmp($received, $expected, "server/dir merge");
}

{
    my $location = "$url/subdir";
    my $expected = "dir: one two three four five six";
    my $received = GET_BODY $location;
    ok t_cmp($received, $expected, "server/dir/subdir merge");
}
