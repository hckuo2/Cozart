# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil qw(t_cmp t_catfile_apache);
use Apache::TestRequest;
use Apache::TestConfig ();

my %modules = (
    registry    => 'ModPerl::Registry',
    registry_bb => 'ModPerl::RegistryBB',
    perlrun     => 'ModPerl::PerlRun',
);

my @aliases = sort keys %modules;

plan tests => @aliases * 1, need 'mod_alias.c';

my $vars = Apache::Test::config()->{vars};
my $script_file = t_catfile_apache $vars->{serverroot}, 'cgi-bin', 'basic.pl';

# extended regex quoting
# CVE-2007-1349 (which doesn't affect any of our shipped handlers)

for my $alias (@aliases) {
    my $url = "/$alias/basic.pl/(";

    ok t_cmp(
        GET_BODY($url),
        "ok $script_file",
        "$modules{$alias} regex in path_info",
    );
}
