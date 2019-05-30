# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_BODY HEAD);

use Apache::TestUtil qw(t_catfile_apache);

plan tests => 4, need [qw(mod_alias.c HTML::HeadParser)], need_lwp;

# need LWP to handle redirects
my $base_url = "/registry/redirect.pl";

{
    my $redirect_path = "/registry/basic.pl";
    my $url = "$base_url?$redirect_path";
    my $vars = Apache::Test::config()->{vars};
    my $script_file = t_catfile_apache $vars->{serverroot}, 'cgi-bin', 'basic.pl';

    ok t_cmp(
        GET_BODY($url),
        "ok $script_file",
        "test redirect: existing target",
       );
}

{
    my $redirect_path = "/registry/does_not_exists.pl";
    my $url = "$base_url?$redirect_path";
    t_client_log_error_is_expected();
    ok t_cmp(
        HEAD($url)->code,
        404,
        "test redirect: non-existing target",
       );
}

{
    local $Apache::TestRequest::RedirectOK = 0;

    my $base_url = "/registry/redirect-cookie.pl";
    my $redirect_path = "/registry/basic.pl";
    my $url = "$base_url?$redirect_path";

    my $response = HEAD $url;

    ok t_cmp(
        $response->code,
        302,
        "test Registry style redirect: status",
       );

    ok t_cmp(
        $response->header('Set-Cookie'),
        "mod_perl=ubercool; path=/",
        "test Registry style redirect: cookie",
       );
}

