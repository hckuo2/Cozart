# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
Apache::TestRequest::user_agent(keep_alive => 1);

plan tests => 2, need 'HTML::HeadParser';

my $module   = 'TestAPR::pool_lifetime';
my $location = '/' . Apache::TestRequest::module2path($module);

for (1..2) {
    my $expected = "Pong";
    my $received = GET $location;

    ok t_cmp(
        $received->content,
        $expected,
        "Pong",
    );
}
