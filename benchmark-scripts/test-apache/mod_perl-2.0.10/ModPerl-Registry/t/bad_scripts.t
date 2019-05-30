# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

plan tests => 1, need 'mod_alias.c';

{
    t_client_log_error_is_expected();
    my $url = "/perlrun/r_inherited.pl";
    my $res = GET($url);
    ok t_cmp(
        $res->code,
        500,
        "the script hasn't declared its private \$r",
       );
}
