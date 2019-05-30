# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = '/TestFilter__in_str_sandwich';

my $expected = join "\n", qw(HEADER BODY TAIL), '';
my $received = POST_BODY $location, content => "BODY\n";

ok t_cmp($received, $expected, "input stream filter sandwich")

