#!perl -T
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::brigade;

plan tests => TestAPRlib::brigade::num_of_tests();

TestAPRlib::brigade::test();
