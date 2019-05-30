# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

my $location = '/TestAPI__rflush';

plan tests => 2;

{
    my $response = GET_BODY "$location?nontied";
    ok t_cmp($response, "[1][2][3][4][56]",
             "non-tied rflush creates bucket brigades");
}

{
    my $response = GET_BODY "$location?tied";
    ok t_cmp($response, "[1][2][3456]",
             "tied STDOUT internal rflush creates bucket brigades");
}

