# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::TestRequest 'GET_BODY_ASSERT';
print GET_BODY_ASSERT "/TestAPI__request_rec/my_path_info?my_args=3";
