# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $location = "/TestModperl__setupenv2";

my %expected = (
    mixed => [qw(loadmodule conf1 <perl> conf2 require conf3
                config_require conf4 perlmodule conf5 conf5
                conf6 conf7 conf8 post_config_require)],
    perl  => [qw(loadmodule <perl> require config_require
                perlmodule post_config_require)],
);

plan tests => 2 + scalar(@{ $expected{mixed} }) + scalar(@{ $expected{perl} });

while (my ($k, $v) = each %expected) {
    my @expected = @$v;
    my $elements = scalar @expected;
    my $received = GET_BODY "$location?$k";
    t_debug "$k: $received";
    my @received = split / /, $received;

    ok t_cmp $received[$_], $expected[$_] for 0..$#expected;

    ok t_cmp scalar(@received), scalar(@expected), "elements";
    if (@received > @expected) {
        t_debug "unexpected elements: " .
            join " ", @received[$elements..$#received];
    }
}

