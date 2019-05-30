# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
#requires C::Scan 0.75+

use lib qw(lib Apache-Test/lib);

use strict;
use Apache2::ParseSource ();
use ModPerl::ParseSource ();
use ModPerl::FunctionMap ();
use ModPerl::WrapXS (); #XXX: we should not need to require this here

my $p = Apache2::ParseSource->new(prefixes => ModPerl::FunctionMap->prefixes,
                                  @ARGV);

$p->parse;

$p->write_constants_pm;

$p->write_functions_pm;

$p->write_structs_pm;

$p = ModPerl::ParseSource->new(@ARGV);

$p->parse;

$p->write_functions_pm;
