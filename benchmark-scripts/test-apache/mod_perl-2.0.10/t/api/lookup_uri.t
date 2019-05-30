# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $uri = "/TestAPI__lookup_uri";

use constant PREFIX => 0;
use constant SUFFIX => 1;

my %opts = (
    first   => [2, 2], # all filters run twice
    second  => [1, 2], # the top level req filter skipped for the subreq
    none    => [1, 1], # no request filters run by subreq
    default => [1, 1], # same as none
);

plan tests => scalar keys %opts;

while (my ($filter, $runs) = each %opts) {
    my $args = "subreq=lookup_uri;filter=$filter";
    my $prefix = "pre+" x $runs->[PREFIX];
    my $suffix = "+suf" x $runs->[SUFFIX];
    my $expected = "$prefix$args$suffix";
    my $received = GET_BODY_ASSERT "$uri?$args";
    ok t_cmp $received, $expected, "$args";
}
