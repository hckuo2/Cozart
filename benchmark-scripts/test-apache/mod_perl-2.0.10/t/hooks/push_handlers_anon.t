# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# the handler is configured in modperl_extra.pl via
# Apache2::ServerUtil->server->add_config

use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY_ASSERT';

my $module = 'TestHooks::push_handlers_anon';
my $url    = Apache::TestRequest::module2url($module);

t_debug("connecting to $url");
print GET_BODY_ASSERT $url;
