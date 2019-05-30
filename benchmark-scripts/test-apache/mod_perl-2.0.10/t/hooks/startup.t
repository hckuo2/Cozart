# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $config = Apache::Test::config();
my $path = Apache::TestRequest::module2path('TestHooks::startup');

my @modules = qw(default TestHooks::startup);

plan tests => scalar @modules;

my $expected = join '', "open_logs ok\n", "post_config ok\n";

for my $module (sort @modules) {

    Apache::TestRequest::module($module);
    my $hostport = Apache::TestRequest::hostport($config);
    t_debug("connecting to $hostport");

    ok t_cmp(GET_BODY_ASSERT("http://$hostport/$path"),
             $expected,
             "testing PostConfig");
}

