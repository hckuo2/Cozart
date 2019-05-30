# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = '/TestFilter__in_bbs_underrun';

# send a message of about 40k, so to make sure that the input filter
# will get several bucket brigades with data (about 8k/brigade)
my $length = 40 * 1024 + 7; # ~40k+ (~6 incoming bucket brigades)
my $data = "x" x $length;
my $received = POST_BODY $location, content => $data;
my $expected = "read $length chars";

ok t_cmp($received, $expected, "input bbs filter underrun test")
