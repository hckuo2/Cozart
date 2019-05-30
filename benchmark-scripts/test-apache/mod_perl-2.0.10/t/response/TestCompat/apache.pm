# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCompat::apache;

# Apache->"method" and Apache::"function" compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use ModPerl::Util ();
use Apache2::compat ();
use Apache::Constants qw(DIR_MAGIC_TYPE OPT_EXECCGI :common :response);

use File::Spec::Functions qw(catfile canonpath);

sub fixup {
    my $r = shift;
    Apache->httpd_conf('Options +ExecCGI');
    OK;
}

sub handler {
    my $r = shift;

    plan $r, tests => 24;

    $r->send_http_header('text/plain');

    ### Apache-> tests
    my $fh = Apache->gensym;
    ok t_cmp(ref($fh), 'GLOB', "Apache->gensym");

    ok t_cmp(Apache->module('mod_perl.c'), 1,
             "Apache2::module('mod_perl.c')");
    ok t_cmp(Apache->module('mod_ne_exists.c'), 0,
             "Apache2::module('mod_ne_exists.c')");

    ok t_cmp(Apache->define('MODPERL2'),
             Apache2::ServerUtil::exists_config_define('MODPERL2'),
             'Apache->define');

    ok t_cmp($r->current_callback,
             'PerlResponseHandler',
             'inside PerlResponseHandler');

    t_server_log_error_is_expected();
    Apache::log_error("Apache::log_error test ok");
    ok 1;

    t_server_log_warn_is_expected();
    Apache->warn('Apache->warn ok');
    ok 1;

    t_server_log_warn_is_expected();
    Apache::warn('Apache::warn ok');
    ok 1;

    t_server_log_warn_is_expected();
    Apache::Server->warn('Apache::Server->warn ok');
    ok 1;

    t_server_log_warn_is_expected();
    Apache::Server::warn('Apache::Server::warn ok');
    ok 1;

    # explicitly imported
    ok t_cmp(DIR_MAGIC_TYPE, "httpd/unix-directory",
             'DIR_MAGIC_TYPE');

    # :response is ignored, but is now aliased in :common
    ok t_cmp(REDIRECT, "302",
             'REDIRECT');

    # from :common
    ok t_cmp(AUTH_REQUIRED, "401",
             'AUTH_REQUIRED');

    ok t_cmp(OK, "0",
             'OK');

    my $exec_cgi = $r->allow_options & Apache2::Const::OPT_EXECCGI;
    ok t_cmp($exec_cgi, Apache2::Const::OPT_EXECCGI, 'Apache->httpd_conf');

    # (Apache||$r)->server_root_relative
    {
        my $server_root = Apache::Test::config()->{vars}->{serverroot};
        ok t_filepath_cmp(canonpath($Apache::Server::CWD),
                          canonpath($server_root),
                          '$server_root');

        ok t_filepath_cmp(canonpath($r->server_root_relative),
                          canonpath($server_root),
                          '$r->server_root_relative()');

        ok t_filepath_cmp(canonpath($r->server_root_relative('conf')),
                          catfile($server_root, 'conf'),
                          "\$r->server_root_relative('conf')");

        ok t_filepath_cmp(canonpath(Apache->server_root_relative('conf')),
                          catfile($server_root, 'conf'),
                          "Apache2::ServerUtil->server_root_relative('conf')");

        ok t_filepath_cmp(canonpath(Apache->server_root_relative),
                          canonpath($server_root),
                          'Apache2::ServerUtil->server_root_relative()');

        my $path = catfile(Apache2::ServerUtil::server_root, 'logs');
        ok t_filepath_cmp(canonpath(Apache->server_root_relative($path)),
                          canonpath($path),
                          "Apache->server_root_relative('$path')");
    }

    ok t_cmp(Apache->unescape_url_info("/foo+bar%20baz"),
             '/foo bar baz',
             'Apache->unescape_url_info');

    ok t_cmp $Apache::Server::Starting,   0, '$Apache::Server::Starting';
    ok t_cmp $Apache::Server::ReStarting, 1, '$Apache::Server::ReStarting';

    OK;
}

1;

__END__
# so we can test whether send_httpd_header() works fine
PerlOptions +ParseHeaders +GlobalRequest
PerlModule TestCompat::apache
PerlFixupHandler TestCompat::apache::fixup
