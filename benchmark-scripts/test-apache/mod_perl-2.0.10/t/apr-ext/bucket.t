#!perl -T
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::bucket;

plan tests => TestAPRlib::bucket::num_of_tests();

TestAPRlib::bucket::test();
