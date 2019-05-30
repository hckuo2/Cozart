# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1, ['include'];

my $location = '/TestFilter__out_str_req_eos';

my $content = 'BODY';
my $prefix = 'PREFIX_';
my $suffix = '_SUFFIX';

my $expected = join '', $prefix, $content, $suffix;
my $received = POST_BODY $location, content => $content;

ok t_cmp($received, $expected,
    "testing the EOS bucket forwarding through the mp filters chains");
