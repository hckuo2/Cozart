# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = "/TestError__syntax";

t_client_log_error_is_expected();
my $res = GET($location);
#t_debug($res->content);
ok t_cmp(
    $res->code,
    500,
    "500 error on syntax error",
   );
