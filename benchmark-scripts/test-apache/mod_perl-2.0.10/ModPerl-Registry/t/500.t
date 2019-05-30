# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

plan tests => 7, need 'mod_alias.c';

{
    # the script changes the status before the run-time error happens,
    # this status change should be ignored
    my $url = "/registry/runtime_error_n_status_change.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        $res->code,
        500,
        "500 error on runtime error (when the script changes the status)",
       );
}

{
    my $url = "/registry/syntax_error.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        $res->code,
        500,
        "500 compile time error (syntax error)",
       );
}

{
    my $url = "/registry/use_error.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        $res->code,
        500,
        "500 compile error on use() failure",
       );
}

{
    my $url = "/registry/missing_headers.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        $res->code,
        500,
        "500 error on missing HTTP headers",
       );
}

{
    # since we have a runtime error before any body is sent, mod_perl
    # has a chance to communicate the return status of the script to
    # Apache before headers are sent, so we get the code 500 in the
    # HTTP headers
    my $url = "/registry/runtime_error.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        $res->code,
        500,
        "500 error on runtime error",
       );
}

{
    # even though we have a runtime error here, the scripts succeeds
    # to send some body before the error happens and since by that
    # time Apache has already sent the headers, they will include 
    # 200 OK
    my $url = "/registry/runtime_error_plus_body.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        $res->code,
        200,
        "200, followed by a runtime error",
       );

    # the error message is attached after the body
    ok t_cmp($res->content,
             qr/some body.*The server encountered an internal error/ms,
             "200, followed by a runtime error",
            );
}
