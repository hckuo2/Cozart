# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $module = "TestDirective::perlloadmodule3";
my $config   = Apache::Test::config();
my $base_hostport = Apache::TestRequest::hostport($config);
my $path = Apache::TestRequest::module2path($module);

# XXX: probably a good idea to split into more sub-tests, that test
# smaller portions of information, but requires a more elaborate
# logic. Alternatively could use diff($expected, $received).

plan tests => 3;

t_debug("connecting to $base_hostport");
{
    my $expected = <<EOI;
Processing by main server.

Section 1: Main Server
MyAppend   : MainServer
MyList     : ["MainServer"]
MyOverride : MainServer
MyPlus     : 5

Section 2: Location
MyAppend   : MainServer
MyList     : ["MainServer"]
MyOverride : MainServer
MyPlus     : 5
EOI
    my $location = "http://$base_hostport/$path";
    my $received = GET_BODY $location;
    ok t_cmp($expected, $received, "server merge");
}

Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport($config);

t_debug("connecting to $hostport");
{
    my $expected = <<EOI;
Processing by virtual host.

Section 1: Main Server
MyAppend   : MainServer
MyList     : ["MainServer"]
MyOverride : MainServer
MyPlus     : 5

Section 2: Virtual Host
MyAppend   : MainServer VHost
MyList     : ["MainServer", "VHost"]
MyOverride : VHost
MyPlus     : 7

Section 3: Location
MyAppend   : MainServer VHost Dir
MyList     : ["MainServer", "VHost", "Dir"]
MyOverride : Dir
MyPlus     : 10
EOI
    my $location = "http://$hostport/$path";
    my $received = GET_BODY $location;
    ok t_cmp($received, $expected, "server/dir merge");
}

{
    my $expected = <<EOI;
Processing by virtual host.

Section 1: Main Server
MyAppend   : MainServer
MyList     : ["MainServer"]
MyOverride : MainServer
MyPlus     : 5

Section 2: Virtual Host
MyAppend   : MainServer VHost
MyList     : ["MainServer", "VHost"]
MyOverride : VHost
MyPlus     : 7

Section 3: Location
MyAppend   : MainServer VHost Dir SubDir
MyList     : ["MainServer", "VHost", "Dir", "SubDir"]
MyOverride : SubDir
MyPlus     : 11
EOI

    my $location = "http://$hostport/$path/subdir";
    my $received = GET_BODY $location;
    ok t_cmp($received, $expected, "server/dir/subdir merge");
}
