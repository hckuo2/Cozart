# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

# testing various binary responses

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 2, need 'mod_alias.c';

# 2 sub-tests
{
    # favicon.ico and other .ico image/x-icon images start with
    # sequence:
    my $expected = "\000\000\001\000";
    my $location = "/registry/bin_resp_start_0.pl";
    #my $location = "/cgi-bin/bin_resp_start_0.pl";

    my $received = GET_BODY_ASSERT $location;

    #t_debug "$received";

    ok t_cmp(length($received), length($expected), "image size");

    t_debug "comparing the binary contents";
    ok $expected eq $received;
}


