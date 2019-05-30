# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache2::ServerUtil ();

$TestVhost::config::restart_count = Apache2::ServerUtil::restart_count();

1;
