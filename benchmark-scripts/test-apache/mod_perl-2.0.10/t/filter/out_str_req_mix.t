# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1, ['include'];

my $location = '/TestFilter__out_str_req_mix';

my $content = '<!--#include virtual="/includes/REMOVEclear.shtml" -->';

my $expected = 'This is a clear text';
my $received = POST_BODY $location, content => $content;
$received =~ s{\r?\n$}{};

ok t_cmp($expected, $received,
    "mixing output httpd and mod_perl filters, while preserving order");
