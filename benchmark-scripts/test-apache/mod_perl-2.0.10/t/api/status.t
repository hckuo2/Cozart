# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

# testing $r->status/status_line

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 6;

my $location = "/TestAPI__status";

{
    # test a valid HTTP/1.1 status code (303). In this test
    # the handler returns OK, but sets a custom status. Apache will
    # lookup the message "See Other" on its own
    my $code = 303; # Apache2::Const::HTTP_SEE_OTHER
    my $message = "See Other";
    my $res = GET "$location?$code=";
    ok t_cmp $res->code, $code, "code";
    ok t_cmp $res->message, $message, "code message";
    ok t_cmp $res->content, "", "content";
}

{
    # test a non-existing HTTP/1.1 status code (499). In this test
    # the handler returns OK, but sets a custom status_line.
    # it also tries to set status (to a different value), but it
    # should be ignored by Apache, since status_line is supposed to
    # override status. the handler also sets a custom code message
    #   modules/http/http_filters.c r372958
    #   httpd 'zaps' the status_line if it doesn't match the status
    #   as of 2.2.1 (not released) so 2.2.2 (released)

    my $code = 499; # not in HTTP/1.1
    my $message = "FooBared";
    my $res = GET "$location?$code=$message";
    ok t_cmp $res->code, $code, "code";
    ok t_cmp $res->message, $message, "code message";
    ok t_cmp $res->content, "", "content";
}

