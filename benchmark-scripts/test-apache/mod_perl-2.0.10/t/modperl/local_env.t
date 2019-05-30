# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1, skip_reason('local %ENV is still broken');

my $module = 'TestModperl::local_env';
my $url    = Apache::TestRequest::module2url($module);

t_debug "connecting to $url";
print GET_BODY_ASSERT $url;
