# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# test the situation where a native apache response filter is
# configured outside the <Location> block with PerlSet*Filter
# directive. In this case we need to make sure that mod_perl doesn't
# try to add it as connection filter

# see the server side config in t/conf/extra.conf.in

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY_ASSERT';
use TestCommon::LogDiff;
use File::Spec::Functions qw(catfile);

my $path = catfile Apache::Test::vars('serverroot'),
    qw(logs error_log);

plan tests => 2, need 'include', 'HTML::HeadParser';

my $module = 'filter_out_apache';
my $config = Apache::Test::config();

Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport($config);
t_debug("connecting to $hostport");

my $logdiff = TestCommon::LogDiff->new($path);

my $expected = qr/welcome to/;
my $response = GET_BODY_ASSERT "http://$hostport/";
ok t_cmp $response, qr/$expected/, "success";

ok !t_cmp $logdiff->diff,
    qr/content filter was added without a request: includes/,
    "shouldn't [error] complain in error_log";
