# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = '/TestFilter__in_bbs_consume';

# send a message bigger than 8k, so to make sure that the input filter
# will get more than one bucket brigade with data.
my $length = 40 * 1024 + 7; # ~40k+ (~6 incoming bucket brigades)
my $expected = join '', 'a'..'z';
my $data = $expected . "x" x $length;
my $received = POST_BODY $location, content => $data;

ok t_cmp($received, $expected, "input bbs filter full consume")
