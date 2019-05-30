# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

plan tests => 10, need [qw(mod_alias.c HTML::HeadParser)];

my $url = "/registry/304.pl";

{
    # not modified
    my $if_modified_since = 'Sun, 29 Oct 2000 15:55:00 GMT';
    my $res = GET($url, 'If-Modified-Since' => $if_modified_since);

    ok t_cmp(
        $res->code,
        304,
        "test HTTP_NOT_MODIFIED (304 status)",
    );

    ok t_cmp(
        $res->content,
        '',
        "test HTTP_NOT_MODIFIED (null body)",
    );

    #t_debug $res->as_string;
}

{
    # full response cases:
    # 1) the resource has been modified since the If-Modified-Since date
    # 2) bogus If-Modified-Since date => is considered as a 
    #    non-If-Modified-Since require
    # 
    my %dates = (
        'Sun, 29 Oct 2000 15:43:28 GMT' => "the resource was modified since #1",
        'Sun, 28 Oct 2000 15:43:29 GMT' => "the resource was modified since #2",
        'Thu, 32 Jun 1999 24:59:59 MIT' => "bogus If-Modified-Since #1",
        'Thu Juk 99 00:00:00 9999 FUK'  => "bogus If-Modified-Since #2",
    );
    my $received = '<html><head></head><body>Test</body></html>';
    while ( my ($if_modified_since, $debug) = each %dates) {
        my $res = GET($url, 'If-Modified-Since' => $if_modified_since);
        t_debug "If-Modified-Since $if_modified_since";
        ok t_cmp(
            $res->code,
            200,
            "$debug (code)"
        );

        ok t_cmp(
            $res->content,
            $received,
            "$debug (body)"
        );

        #t_debug $res->as_string;
    }
}
