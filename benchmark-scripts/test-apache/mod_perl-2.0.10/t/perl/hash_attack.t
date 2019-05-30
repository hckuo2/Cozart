# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache::TestRequest 'GET_BODY_ASSERT';

plan tests => 1,
    need { "relevant only for perl 5.8.2 and up to 5.17.6" => ($] >= 5.008002 && $] < 5.017006) };

my $expected = "ok";
my $received = GET_BODY_ASSERT "/TestPerl__hash_attack";
ok($expected eq $received);
