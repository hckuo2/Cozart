# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 2;

my $location = "/TestApache__cgihandler";

my $expected = "1..3\nok 1\nok 2\nok 3\n";

my $received = POST_BODY $location, content => $expected;

ok t_cmp $received, $expected, "POST cgihandler";

$received = GET_BODY $location;

ok t_cmp $received, $expected, "GET cgihandler";
