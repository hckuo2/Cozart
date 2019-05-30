#!/usr/bin/perl -w
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use ModPerl::Config ();

print ModPerl::Config::as_string();
