# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# the handler is configured in modperl_extra.pl via
# Apache2::ServerUtil->server->add_config

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest 'GET';

my $module = 'TestVhost::config';
my $url    = Apache::TestRequest::module2url($module);

t_debug("connecting to $url");
my $res = GET $url;

if ($res->is_success) {
    print $res->content;
}
else {
    if ($res->code == 404) {
        my $docroot = Apache::Test::vars('documentroot');
        die "this test gets its <Location> configuration added via " .
            "$docroot/vhost/startup.pl, this could be the cause " .
            "of the failure";
    }
    else {
        die "server side has failed (response code: ", $res->code, "),\n",
            "see t/logs/error_log for more details\n";
    }
}
