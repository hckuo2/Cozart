# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use lib qw(lib Apache-Test/lib);

use Apache::TestConfig (); # needed to resolve circular use dependency

use ModPerl::WrapXS ();

my $xs = ModPerl::WrapXS->new;

$xs->generate;

