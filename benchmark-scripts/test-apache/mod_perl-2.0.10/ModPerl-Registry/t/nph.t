# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 6, need 'mod_alias.c';

my $url = "/nph/nph-foo.pl";

my %expected = (
    code    => '250',
    body    => "non-parsed headers body",
    headers => {
        'content-type' => 'text/text',
        'pragma' => 'no-cache',
        'cache-control' => 'must-revalidate, no-cache, no-store',
        'expires' => '-1',
    },
);

my $res = GET $url;

my %received = (
    code    => $res->code,
    body    => $res->content,
    headers => $res->headers, # LWP lc's the headers
);

for my $key (keys %expected) {
    my $expected = $expected{$key};
    my $received = $received{$key};
    if ($key eq 'headers') {
        for my $header (keys %$expected) {
            ok t_cmp(
                $received->{$header},
                $expected->{$header},
                "test header $header"
            );
        }
    }
    else {
        ok t_cmp(
            $received,
            $expected,
            "test key: $key"
        );
    }
}

