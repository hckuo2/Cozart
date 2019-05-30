#!perl -T
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache2::Build ();

# XXX: only when apr-config is found APR will be linked against
# libapr/libaprutil, probably need a more intuitive method for this
# prerequisite
# also need to check whether we build against the source tree, in
# which case we APR.so won't be linked against libapr/libaprutil
# In order to do this for all the apr-ext tests, could have
# a wrapper around plan() that does a check like
#######
# my $build = Apache2::Build->build_config;
#
# my $has_apr_config = $build->{apr_config_path} &&
#    !$build->httpd_is_source_tree;
# plan tests => TestAPRlib::uuid::num_of_tests(),
#    need {"the build couldn't find apr-config" => $has_apr_config};
######
# that is called from some TestAPRlib::common.

use TestAPRlib::uuid;

plan tests => TestAPRlib::uuid::num_of_tests();

TestAPRlib::uuid::test();
