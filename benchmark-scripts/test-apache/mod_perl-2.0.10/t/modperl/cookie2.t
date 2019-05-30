# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

# The Cookie HTTP header can be accessed via $r->headers_in and in certain
# situations via $ENV{HTTP_COOKIE}.
#
# in this test we shouldn't be able get the cookie via %ENV,
# since 'SetHandler modperl' doesn't set up CGI env var. unless the
# handler calls "$r->subprocess_env" by itself
#
# since the test is run against the same interpreter we also test that
# the cookie value doesn't persist if it makes it to %ENV.

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
Apache::TestRequest::user_agent(keep_alive => 1);

plan tests => 3, need 'HTML::HeadParser';

my $module   = 'TestModperl::cookie2';
my $location = '/' . Apache::TestRequest::module2path($module);

my %expected =
(
    header         => "header",
    subprocess_env => "subprocess_env",
    env            => '',
);

my @tests_ordered = qw(header subprocess_env env);

for my $test (@tests_ordered) {
    my $cookie = "key=$test";

    my $received = GET "$location?$test", Cookie => $cookie;

    ok t_cmp(
        $received->content,
        $expected{$test},
        "perl-script+SetupEnv/cookie: $test",
    );
}
