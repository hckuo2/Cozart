# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# the handler is configured in modperl_extra.pl via
# Apache2::ServerUtil->server->add_config
use Apache::TestRequest 'GET_BODY_ASSERT';

print GET_BODY_ASSERT "/apache/add_config";
