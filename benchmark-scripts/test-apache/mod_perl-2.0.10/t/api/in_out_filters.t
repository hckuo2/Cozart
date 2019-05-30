# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1;

my $location = '/TestAPI__in_out_filters';

my $content = join '', 'AA'..'ZZ', 1..99999;

my $expected = lc $content;
my $received = POST_BODY $location, content => $content;

# don't use t_cmp in this test, because the data length is 500K.
# You don't want to see 500K * 2 when you run t/TEST -verbose

ok $received eq $expected;

