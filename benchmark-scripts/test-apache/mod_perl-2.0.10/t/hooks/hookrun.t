# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $module = 'TestHooks::hookrun';
my $config = Apache::Test::config();
my $path = Apache::TestRequest::module2path($module);

Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport($config);
t_debug("connecting to $hostport");

plan tests => 10;

my $ret = GET "http://$hostport/$path?die";
ok t_cmp $ret->code, 500, '$r->die';

my $body = GET_BODY_ASSERT "http://$hostport/$path?normal";
for my $line (split /\n/, $body) {
    my ($phase, $value) = split /:/, $line;
    ok t_cmp $value, 1, "$phase";
}
