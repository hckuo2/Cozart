# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use TestCommon::SameInterp;

use File::Spec::Functions;

# this test tests how various registry packages cache and flush the
# scripts their run, and whether they check modification on the disk
# or not. We don't test the closure side effect, but we use it as a
# test aid. The tests makes sure that they run through the same
# interpreter all the time (in case that the server is running more
# than one interpreter)

my @modules = qw(registry registry_bb perlrun);

plan tests => 6, need [qw(mod_alias.c HTML::HeadParser)];

my $cfg = Apache::Test::config();

my $file = 'closure.pl';
my $path = catfile $cfg->{vars}->{serverroot}, 'cgi-bin', $file;
my $orig_mtime = (stat($path))[8];

# for all sub-tests in this test, we make sure that we always get onto
# the same interpreter. if this doesn't happen we skip the sub-test or
# a group of them, where several sub-tests rely on each other.

{
    # ModPerl::PerlRun
    # always flush
    # no cache

    my $url = "/same_interp/perlrun/$file";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # should be no closure effect, always returns 1
    my $first  = same_interp_req_body($same_interp, \&GET, $url);
    my $second = same_interp_req_body($same_interp, \&GET, $url);
    same_interp_skip_not_found(
        (scalar(grep defined, $first, $second) != 2),
        $first && $second && ($second - $first),
        0,
        "never the closure problem",
    );

    # modify the file
    touch_mtime($path);

    # it doesn't matter, since the script is not cached anyway
    my $third = same_interp_req_body($same_interp, \&GET, $url);
    same_interp_skip_not_found(
        (scalar(grep defined, $first, $second, $third) != 3),
        $third,
        1,
        "never the closure problem",
    );

    reset_mtime($path);
}

{
    # ModPerl::Registry
    # no flush
    # cache, but reload on modification
    my $url = "/same_interp/registry/$file";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # we don't know what other test has called this uri before, so we
    # check the difference between two subsequent calls. In this case
    # the difference should be 1.
    my $first  = same_interp_req_body($same_interp, \&GET, $url);
    my $second = same_interp_req_body($same_interp, \&GET, $url);
    same_interp_skip_not_found(
        (scalar(grep defined, $first, $second) != 2),
        $first && $second && ($second - $first),
        1,
        "the closure problem should exist",
    );

    # modify the file
    touch_mtime($path);

    # should not notice closure effect on the first request
    my $third = same_interp_req_body($same_interp, \&GET, $url);
    same_interp_skip_not_found(
        (scalar(grep defined, $first, $second, $third) != 3),
        $third,
        1,
        "no closure on the first request",
    );

    reset_mtime($path);
}

{
    # ModPerl::RegistryBB
    # no flush
    # cache once, don't check for mods
    my $url = "/same_interp/registry_bb/$file";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # we don't know what other test has called this uri before, so we
    # check the difference between two subsequent calls. In this case
    # the difference should be 1.
    my $first  = same_interp_req_body($same_interp, \&GET, $url);
    my $second = same_interp_req_body($same_interp, \&GET, $url);
    same_interp_skip_not_found(
        (scalar(grep defined, $first, $second) != 2),
        $first && $second && ($second - $first),
        1,
        "the closure problem should exist",
    );

    # modify the file
    touch_mtime($path);

    # modification shouldn't be noticed
    my $third = same_interp_req_body($same_interp, \&GET, $url);
    same_interp_skip_not_found(
        (scalar(grep defined, $first, $second, $third) != 3),
        $first && $second && $third - $second,
        1,
        "no reload on modification, the closure problem persists",
    );

    reset_mtime($path);
}

sub touch_mtime {
    my $file = shift;
    # push the mtime into the future (at least 2 secs to work on win32)
    # so ModPerl::Registry will re-compile the package
    my $time = time + 5; # make it 5 to be sure
    utime $time, $time, $file;
}

sub reset_mtime {
    my $file = shift;
    # reset  the timestamp to the original mod-time
    utime $orig_mtime, $orig_mtime, $file;
}
