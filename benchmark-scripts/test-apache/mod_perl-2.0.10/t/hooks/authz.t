# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 4, need need_lwp, 'HTML::HeadParser';

my $location = "/TestHooks__authz";

ok ! GET_OK $location;

my $rc = GET_RC $location;

ok $rc == 401;

ok GET_OK $location, username => 'dougm', password => 'foo';

# since LWP 5.815, the user agent retains credentials
# tell Apache::TestRequest to reinitialize its global agent
Apache::TestRequest::user_agent(reset => 1);

ok ! GET_OK $location, username => 'jobbob', password => 'whatever';


