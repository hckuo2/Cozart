# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 6, need 'HTML::HeadParser';

my $location = '/TestAPI__err_headers_out';

{
    # with 2xx responses any of the err_headers_out and headers_out
    # headers make it through

    my $res = GET "$location?200";

    #t_debug $res->as_string;

    ok t_cmp $res->code, 200, "OK";

    # HTTP::Headers 6.00 makes the next 2 tests fail. When the response comes
    # in the header name is stored as "x-err_headers_out". But when it is to
    # be read below it is referred as "x-err-headers-out" and hence not found.
    local $HTTP::Headers::TRANSLATE_UNDERSCORE=
	$HTTP::Headers::TRANSLATE_UNDERSCORE;
    undef $HTTP::Headers::TRANSLATE_UNDERSCORE
	if defined HTTP::Headers->VERSION and HTTP::Headers->VERSION >= 6.00;

    ok t_cmp $res->header('X-err_headers_out'), "err_headers_out",
        "X-err_headers_out: made it";

    ok t_cmp $res->header('X-headers_out'), "headers_out",
        "X-headers_out: made it";
}

{
    # with non-2xx responses only the err_headers_out headers make it
    # through. the headers_out do not make it.

    my $res = GET "$location?404";

    #t_debug $res->as_string;

    ok t_cmp $res->code, 404, "not found";

    # HTTP::Headers 6.00 makes this test fail. When the response comes in
    # the header name is stored as "x-err_headers_out". But when it is to
    # be read below it is referred as "x-err-headers-out" and hence not found.
    local $HTTP::Headers::TRANSLATE_UNDERSCORE=
	$HTTP::Headers::TRANSLATE_UNDERSCORE;
    undef $HTTP::Headers::TRANSLATE_UNDERSCORE
	if defined HTTP::Headers->VERSION and HTTP::Headers->VERSION >= 6.00;

    ok t_cmp $res->header('X-err_headers_out'), "err_headers_out",
        "X-err_headers_out: made it";

    ok !$res->header('X-headers_out');
}

