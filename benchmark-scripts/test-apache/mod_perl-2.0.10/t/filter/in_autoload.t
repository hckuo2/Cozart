# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = '/TestFilter__in_autoload';

my $data = "[Foo BaR] ";
my $expected = lc $data;
my $received = POST_BODY $location, content => $data;

ok t_cmp($received, $expected, "input stream filter lc autoloaded")

