# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);
use TestCommon::SameInterp;

plan tests => 2, need [qw(mod_alias.c HTML::HeadParser)];

my $url = "/same_interp/perlrun/perlrun_extload.pl";
my $same_interp = Apache::TestRequest::same_interp_tie($url);

for (1..2) {
    # should not fail on the second request
    my $res = same_interp_req_body($same_interp, \&GET, $url);
    same_interp_skip_not_found(
        !defined($res),
        $res,
        "d1nd1234",
        "PerlRun requiring an external lib with subs",
    );
}

