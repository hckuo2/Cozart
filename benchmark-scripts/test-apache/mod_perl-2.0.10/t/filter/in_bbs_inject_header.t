# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::TestRequest;

my $module = 'TestFilter::in_bbs_inject_header';
my $location = "/" . Apache::TestRequest::module2path($module);

Apache::TestRequest::scheme('http'); #force http for t/TEST -ssl
Apache::TestRequest::module($module);

my $config = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
t_debug("connecting to $hostport");

my $content = "This body shouldn't be seen by the filter";

my $header1_key = 'X-My-Protocol';
my $header1_val = 'POST-IT';

my %headers = (
    'X-Extra-Header2' => 'Value 2',
    'X-Extra-Header3' => 'Value 3',
);

my $keep_alive_times     = 4;
my $non_keep_alive_times = 4;
my $tests = 2 + keys %headers;
my $times = $non_keep_alive_times + $keep_alive_times + 1;

plan tests => $tests * $times;

# try non-keepalive conn
validate(POST($location, content => $content)) for 1..$non_keep_alive_times;

# try keepalive conns
Apache::TestRequest::user_agent(reset => 1, keep_alive => 1);
validate(POST($location, content => $content)) for 1..$keep_alive_times;

# try non-keepalive conn
Apache::TestRequest::user_agent(reset => 1, keep_alive => 0);
validate(POST($location, content => $content));

# 4 sub-tests
sub validate {
    my $res = shift;

    die join "\n",
        "request has failed (the response code was: " . $res->code . ")",
        "see t/logs/error_log for more details\n" unless $res->is_success;

    ok t_cmp($res->content, $content, "body");

    ok t_cmp($res->header($header1_key),
             $header1_val,
             "injected header $header1_key");

    for my $key (sort keys %headers) {
        ok t_cmp($res->header($key),
                 $headers{$key},
                 "injected header $key");
    }
}
