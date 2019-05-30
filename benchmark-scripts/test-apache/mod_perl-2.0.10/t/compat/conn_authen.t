# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, need need_lwp, need_auth, 'HTML::HeadParser';

my $location = "/TestCompat__conn_authen";

ok GET_OK $location, username => 'dougm', password => 'foo';

