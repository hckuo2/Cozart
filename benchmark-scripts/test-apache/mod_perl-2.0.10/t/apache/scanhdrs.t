# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 4;

my $module = 'TestApache::scanhdrs';
my $location = "/" . Apache::TestRequest::module2path($module);

my $res = GET $location;

t_debug $res->as_string;

ok t_cmp($res->content, qr/^ok 1$/m);

ok t_cmp($res->header('Content-Type'),
         'text/test-output',
         "standard header");

ok t_cmp($res->header('X-Perl-Module'),
         $module,
         "custom header");

ok t_cmp($res->message, qr/beer/);
