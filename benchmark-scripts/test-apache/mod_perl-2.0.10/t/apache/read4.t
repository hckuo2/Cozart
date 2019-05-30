# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use Apache::TestRequest 'POST_BODY_ASSERT';
print POST_BODY_ASSERT "/TestApache__read4",
    content => "foobar"x2;
