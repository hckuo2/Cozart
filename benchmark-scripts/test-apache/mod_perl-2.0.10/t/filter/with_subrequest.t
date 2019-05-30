use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, need 'mod_alias';

my $location = "/with_subrequest/Makefile";

my $str = GET_BODY $location;

ok $str !~ /[A-Z]/;
