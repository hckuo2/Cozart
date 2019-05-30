# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

# see the explanations in in_str_consume.pm

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = '/TestFilter__in_str_consume';

my $data = "*" x 80000; # about 78K => ~10 bbs
my $expected = 105;

t_debug "sent "  . length($data) . "B, expecting ${expected}B to make through";

my $received = POST_BODY $location, content => $data;

ok t_cmp($received, $expected, "input stream filter partial consume")
