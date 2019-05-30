# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil qw(t_cmp t_catfile_apache t_client_log_error_is_expected);
use Apache::TestRequest;
use Apache::TestConfig ();

my %modules = (
    registry    => 'ModPerl::Registry',
    registry_bb => 'ModPerl::RegistryBB',
    perlrun     => 'ModPerl::PerlRun',
);

my @aliases = sort keys %modules;

plan tests => @aliases * 5 + 3, need 'mod_alias.c';

my $vars = Apache::Test::config()->{vars};
my $script_file = t_catfile_apache $vars->{serverroot}, 'cgi-bin', 'basic.pl';

# very basic compilation/response test
for my $alias (@aliases) {
    my $url = "/$alias/basic.pl";

    ok t_cmp(
        GET_BODY($url),
        "ok $script_file",
        "$modules{$alias} basic cgi test",
    );
}

# test non-executable bit (it should be executed w/o a problem)
for my $alias (@aliases) {
    if (Apache::TestConfig::WIN32) {
        skip "non-executable bit test for Win32", 0;
        next;
    }
    my $url = "/$alias/not_executable.pl";

    t_client_log_error_is_expected();
    ok t_cmp(
        HEAD($url)->code,
        200,
        "$modules{$alias} non-executable file",
    );
}

# test environment pre-set
for my $alias (@aliases) {
    my $url = "/$alias/env.pl?foo=bar";

    ok t_cmp(
        GET_BODY($url),
        "foo=bar",
        "$modules{$alias} mod_cgi-like environment pre-set",
    );
}

# require (actually chdir test)
for my $alias (@aliases) {
    my $url = "/$alias/require.pl";

    ok t_cmp(
        GET_BODY($url),
        "it works",
        "$modules{$alias} mod_cgi-like environment pre-set",
    );
}


# exit
for my $alias (@aliases) {
    my $url = "/$alias/exit.pl";

    ok t_cmp(
        GET_BODY_ASSERT($url),
        "before exit",
        "$modules{$alias} mod_cgi-like environment pre-set",
    );
}



# test method handlers
{
    my $url = "/registry_oo_conf/env.pl?foo=bar";
    ok t_cmp(
        GET_BODY($url),
        "foo=bar",
        "ModPerl::Registry->handler mod_cgi-like environment pre-set",
    );
}

# test mod_perl api usage
{
    my $url = "/registry/content_type.pl";
    ok t_cmp(
        GET_BODY($url),
        "ok",
        "\$r->content_type('text/plain')",
    );
}


# test that files with .html extension, which are configured to run as
# scripts get the headerparse stage working: the default mime handler
# sets $r->content_type for .html files, so we can't rely on
# content_type not being set in making the decision whether to parse
# headers or not
{
    my $url = "/registry/send_headers.html";
    my $res = GET $url;
    ok t_cmp(
        $res->content_type,
        "text/plain",
        "script's content-type",
    );
}
