# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::TestRequest;
use Apache::Test;
use Apache::TestUtil;

my $module   = "TestHooks::stacked_handlers2";
Apache::TestRequest::module($module);

my $config   = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
my $path     = Apache::TestRequest::module2path($module);

my $location = "http://$hostport/$path";

t_debug("connecting to $location");

plan tests => 1;

my $expected = q!ran 2 PerlPostReadRequestHandler handlers
ran 1 PerlTransHandler handlers
ran 1 PerlMapToStorageHandler handlers
ran 4 PerlHeaderParserHandler handlers
ran 2 PerlAccessHandler handlers
ran 2 PerlAuthenHandler handlers
ran 2 PerlAuthzHandler handlers
ran 1 PerlTypeHandler handlers
ran 4 PerlFixupHandler handlers
ran 2 PerlResponseHandler handlers
ran 2 PerlOutputFilterHandler handlers!;

chomp(my $received = GET_BODY_ASSERT $location);

ok t_cmp($received, $expected, "stacked_handlers");
