# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 4, need 'HTML::HeadParser';

my $location = "/TestHooks__access";

ok ! GET_OK $location;

my $rc = GET_RC $location;

ok $rc == 403;

ok GET_OK $location, 'X-Forwarded-For' => '127.0.0.1';

ok ! GET_OK $location, 'X-Forwarded-For' => '666.0.0.1';


