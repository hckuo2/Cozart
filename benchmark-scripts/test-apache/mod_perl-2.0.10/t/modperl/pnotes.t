# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::TestRequest qw(GET_BODY_ASSERT);
use Apache::Test;
use Apache::TestUtil;

my $module = 'TestModperl::pnotes';
my $url    = Apache::TestRequest::module2url($module);

t_debug("connecting to $url");

plan tests => (26 * 3), need_lwp;

# first with keepalives
Apache::TestRequest::user_agent(reset => 1, keep_alive => 1);
t_debug("issuing first request");
print GET_BODY_ASSERT "$url?1";

# now close the connection
t_debug("issuing second request");
print GET_BODY_ASSERT "$url?2", Connection => 'close';

# finally, check for a cleared $c->pnotes
t_debug("issuing final request");
print GET_BODY_ASSERT "$url?3";

