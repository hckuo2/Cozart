# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 2;

my $location = "/TestModperl__readline";

my $expect = join "\n", map { $_ x 24 } 'a'..'e';

my $str = POST_BODY $location, content => $expect;

ok $str;

ok t_cmp($str, $expect, 'readline');

