# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::TestRequest;

my $location = '/TestFilter__in_bbs_body';

print GET_BODY_ASSERT $location;

for my $x (2..3) {
    my $data = scalar reverse "ok $x\n";
    print POST_BODY_ASSERT $location, content => $data;
}
