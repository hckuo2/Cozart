# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $uri = "/TestAPI__internal_redirect_handler";

my @ct_types = qw(text/plain text/html);

plan tests => scalar @ct_types;

for my $type (@ct_types) {
    my $expected = $type;
    my $received = GET_BODY_ASSERT "$uri?ct=$type";
    ok t_cmp $received, $expected, "Content-type: $type";
}
