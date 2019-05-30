# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::server_const;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use File::Spec::Functions qw(canonpath);

use Apache2::ServerUtil ();
use Apache2::Process ();

use APR::Pool ();

use Apache2::Const -compile => 'OK';

my $cfg = Apache::Test::config;

my $root  = $cfg->{vars}->{serverroot};
my $built = $cfg->{httpd_info}->{BUILT};
my $version = $cfg->{httpd_info}->{VERSION};

sub handler {

    my $r = shift;

    plan $r, tests => 6;

    # test Apache2::ServerUtil constant subroutines

    ok t_filepath_cmp(canonpath(Apache2::ServerUtil::server_root),
                      canonpath($root),
                      'Apache2::ServerUtil::server_root()');

    ok t_cmp(Apache2::ServerUtil::get_server_built,
             $built,
             'Apache2::ServerUtil::get_server_built()');

    my $server_descr = Apache2::ServerUtil::get_server_description;
    ok t_cmp($server_descr, qr/^\Q$version\E/,
             'Apache2::ServerUtil::get_server_description()');

    # added via $s->add_version_component in t/conf/modperl_extra.pl
    ok t_cmp($server_descr, qr!\bworld domination series/2\.0\b!,
             'Apache2::ServerUtil::get_server_description() -- component');

    # assuming ServerTokens Full (default) the banner equals description
    ok t_cmp(Apache2::ServerUtil::get_server_banner, $server_descr,
             'Apache2::ServerUtil::get_server_banner()');

    # version is just an alias for banner
    ok t_cmp(Apache2::ServerUtil::get_server_version, $server_descr,
             'Apache2::ServerUtil::get_server_version()');

    Apache2::Const::OK;
}

1;

__END__
