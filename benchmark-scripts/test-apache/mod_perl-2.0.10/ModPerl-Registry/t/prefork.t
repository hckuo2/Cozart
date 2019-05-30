# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use Apache::TestConfig ();

use Apache2::Build ();

my $mpm_is_threaded = Apache2::Build->build_config->mpm_is_threaded();

my %modules = (
    registry         => 'ModPerl::Registry',
    perlrun          => 'ModPerl::PerlRun',
    registry_prefork => 'ModPerl::RegistryPrefork',
    perlrun_prefork  => 'ModPerl::PerlRunPrefork',
);

my @aliases = sort keys %modules;

plan tests => 1*@aliases, need 'mod_alias.c',
    { "can't run under threaded MPMs" => !$mpm_is_threaded };

my $script = "prefork.pl";

# very basic compilation/response test
for my $alias (qw(registry_prefork perlrun_prefork)) {
    my $url = "/$alias/$script";

    #t_debug "$url";
    ok t_cmp GET_BODY($url), "ok $script", "$modules{$alias} test";
}

# the order is important, we also want to check that prefork specific
# modules didn't affect the cwd of other modules

# the normal handlers should not find the script in the cwd, as they
# don't chdir to its directory before running the script
for my $alias (qw(registry perlrun)) {
    my $url = "/$alias/$script";

    #t_debug "$url";
    ok t_cmp GET_BODY($url), 
        qr/prefork didn't chdir into the scripts directory/,
            "$modules{$alias} test";
}
