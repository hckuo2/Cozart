# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1;

my $expected = "F_O_O_b_a_r_";
my $location = '/TestFilter__out_str_remove';
my $response = GET_BODY $location;
ok t_cmp($response, $expected, "a filter that removes itself");

