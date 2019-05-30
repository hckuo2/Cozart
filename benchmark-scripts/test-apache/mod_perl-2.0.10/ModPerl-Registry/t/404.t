# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_BODY GET);

plan tests => 2, need [qw(mod_alias.c HTML::HeadParser)];

{
    t_client_log_error_is_expected();
    my $url = "/error_document/cannot_be_found";
    my $response = "Oops, can't find the requested doc";
    ok t_cmp(
        GET_BODY($url),
        $response,
        "test ErrorDocument"
    );
}


{
    my $url = "/registry/status_change.pl";
    my $res = GET($url);
    ok t_cmp(
        $res->code,
        404,
        "the script has changed the status to 404"
    );
}
