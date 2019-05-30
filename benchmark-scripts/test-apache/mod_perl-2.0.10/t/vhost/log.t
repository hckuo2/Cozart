# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY_ASSERT';

my $module = 'TestVhost::log';
my $url    = Apache::TestRequest::module2url($module);

t_debug("connecting to $url");
print GET_BODY_ASSERT $url;

