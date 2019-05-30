# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

# test BEGIN/END blocks's behavior

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use TestCommon::SameInterp;

my %modules = (
    registry    => 'ModPerl::Registry',
    registry_bb => 'ModPerl::RegistryBB',
    perlrun     => 'ModPerl::PerlRun',
);

my @aliases = sort keys %modules;

plan tests => @aliases * 4, need [qw(mod_alias.c HTML::HeadParser)];

{
    # PerlRun always run BEGIN/END since it's never cached

    # see also t/perlrun_extload.t which exercises BEGIN/END blocks
    # from external modules loaded from PerlRun scripts

    my $alias = "perlrun";
    my $url = "/same_interp/$alias/special_blocks.pl";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # if one sub-test has failed to run on the same interpreter, skip
    # the rest in the same group
    my $skip = 0;

    my $res = same_interp_req_body($same_interp, \&GET, "$url?begin");
    $skip++ unless defined $res;
    same_interp_skip_not_found(
        $skip,
        $res,
        "begin ok",
        "$modules{$alias} is running BEGIN blocks on the first request",
    );

    $res = $skip ? undef : same_interp_req_body($same_interp, \&GET,
                                                "$url?begin");
    $skip++ unless defined $res;
    same_interp_skip_not_found(
        $skip,
        $res,
        "begin ok",
        "$modules{$alias} is running BEGIN blocks on the second request",
    );

    $res = $skip ? undef : same_interp_req_body($same_interp, \&GET,
                                                "$url?end");
    $skip++ unless defined $res;
    same_interp_skip_not_found(
        $skip,
        $res,
        "end ok",
        "$modules{$alias} is running END blocks on the third request",
    );

    $res = $skip ? undef : same_interp_req_body($same_interp, \&GET,
                                                "$url?end");
    $skip++ unless defined $res;
    same_interp_skip_not_found(
        $skip,
        $res,
        "end ok",
        "$modules{$alias} is running END blocks on the fourth request",
    );
}

# To properly test BEGIN/END blocks in registry implmentations
# that do caching, we need to manually reset the registry* cache
# for each given script, before starting each group of tests.


for my $alias (grep !/^perlrun$/, @aliases) {
    my $url = "/same_interp/$alias/special_blocks.pl";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # if one sub-test has failed to run on the same interpreter, skip
    # the rest in the same group
    my $skip = 0;

    # clear the cache of the registry package for the script in $url
    my $res = same_interp_req_body($same_interp, \&GET, "$url?uncache");
    $skip++ unless defined $res;

    $res = $skip ? undef : same_interp_req_body($same_interp, \&GET,
                                                "$url?begin");
    $skip++ unless defined $res;
    same_interp_skip_not_found(
        $skip,
        $res,
        "begin ok",
        "$modules{$alias} is running BEGIN blocks on the first request",
    );

    $res = $skip ? undef : same_interp_req_body($same_interp, \&GET,
                                                "$url?begin");
    $skip++ unless defined $res;
    t_debug($res);
    same_interp_skip_not_found(
        $skip,
        $res,
        "",
        "$modules{$alias} is not running BEGIN blocks on the second request",
    );

    $same_interp = Apache::TestRequest::same_interp_tie($url);
    $skip = 0;

    # clear the cache of the registry package for the script in $url
    $res = same_interp_req_body($same_interp, \&GET, "$url?uncache");
    $skip++ unless defined $res;

    $res = $skip ? undef : same_interp_req_body($same_interp, \&GET,
                                                "$url?end");
    $skip++ unless defined $res;
    same_interp_skip_not_found(
        $skip,
        $res,
        "end ok",
        "$modules{$alias} is running END blocks on the first request",
    );

    $res = $skip ? undef : same_interp_req_body($same_interp, \&GET,
                                                "$url?end");
    $skip++ unless defined $res;
    same_interp_skip_not_found(
        $skip,
        $res,
        "end ok",
        "$modules{$alias} is running END blocks on the second request",
    );
}
