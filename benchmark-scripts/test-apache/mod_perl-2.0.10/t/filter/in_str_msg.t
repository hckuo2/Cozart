# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use Apache::Test ();
use Apache::TestUtil;

use Apache::TestRequest 'POST_BODY_ASSERT';

my $module = 'TestFilter::in_str_msg';

Apache::TestRequest::scheme('http'); #force http for t/TEST -ssl
Apache::TestRequest::module($module);

my $config = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
t_debug("connecting to $hostport");

print POST_BODY_ASSERT "/input_filter.html", content => "upcase me";
