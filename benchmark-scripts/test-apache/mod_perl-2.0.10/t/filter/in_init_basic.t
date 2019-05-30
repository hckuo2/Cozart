# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1;

my $content = "content ok\n";
# older httpds may run the input request filter twice
my $expected = join '', $content, "init 1\n", "run [12]\n";

my $location = '/TestFilter__in_init_basic';
my $response = POST_BODY $location, content => $content;
ok t_cmp($response, qr/$expected/, "test filter init functionality");
