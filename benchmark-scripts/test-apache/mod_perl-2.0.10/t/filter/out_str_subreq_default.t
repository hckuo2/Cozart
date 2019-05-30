# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

plan tests => 1, need 'mod_alias';

my $location = '/TestFilter__out_str_subreq_default';

my $content1    = "content\n";
my $content2    = "more content\n";
my $filter      = "filter\n";
my $subrequest  = "default-handler subrequest\n";

my $expected = join '', $content1, $subrequest, $content2, $filter;
my $received = GET_BODY $location;
# Win32 and Cygwin fix for line endings
$received =~ s{\r}{}g if Apache::TestConfig::WIN32 || Apache::TestConfig::CYGWIN;

ok t_cmp($received, $expected,
    "testing filter-originated lookup_uri() call to core served URI");
