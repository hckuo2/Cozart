# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1;

my $content = "content ok\n";
my $expected = join '', "init 1\n", "run 1\n", $content, "run 2\n";
# newer Apache versions may make yet another call, so you will see
# "run 3\n" as well.

my $location = '/TestFilter__out_init_basic';
my $response = POST_BODY $location, content => $content;
ok t_cmp($response, qr/^$expected/, "test filter init functionality");
