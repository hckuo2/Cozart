# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::TestRequest qw(GET_BODY_ASSERT);
use Apache::Test;
use Apache::TestUtil;

my $module = 'TestModperl::setupenv';
my $url    = Apache::TestRequest::module2url($module);

t_debug("connecting to $url");

my @locations = ("${url}_mpdefault",
                 "${url}_mpsetup",
                 "${url}_mpdefault",  # make sure %ENV is cleared
                 "${url}_mpvoid",
                 "${url}_mpsetupvoid",
                 "${url}_psdefault",
                 "${url}_psnosetup",
                 "${url}_psvoid",
                 "${url}_psnosetupvoid");

# plan the tests from a handler so we can run
# tests from within handlers across multiple requests
#
# this requires keepalives and a per-connection interpreter
# to make certain we can plan in one request and test in another
# which requires LWP
unless (need_lwp() && need_module('mod_env')) {
    plan tests => 63, 0;
}

Apache::TestRequest::user_agent(keep_alive => 1);
print GET_BODY_ASSERT join '?', $url, scalar @locations;

# this tests for when %ENV is populated with CGI variables
# as well as the contents of the subprocess_env table
#
# see setupenv.pm for a full description of the tests

foreach my $location (@locations) {

    t_debug("trying $location");

    print GET_BODY_ASSERT $location;
}
