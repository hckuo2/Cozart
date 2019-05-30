# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::server_util;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use File::Spec::Functions qw(canonpath catfile);

use Apache2::RequestRec ();
use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::Process ();

use APR::Pool ();

use Apache2::Const -compile => 'OK';

my $serverroot = Apache::Test::config()->{vars}->{serverroot};

our @ISA = qw(Apache2::RequestRec);

sub new {
    my $class = shift;
    my $r = shift;
    bless { r => $r }, $class;
}

sub handler {
    my $r = shift;

    plan $r, tests => 17;

    {
        my $s = $r->server;
        my @expected = qw(ModPerl::Test::exit_handler TestExit::FromPerlModule::exit_handler);
        my @handlers =
            @{ $s->get_handlers('PerlChildExitHandler') || []};
        ok t_cmp(scalar(@handlers), scalar(@expected), "get_handlers");
    }

    t_debug('Apache2::ServerUtil::exists_config_define');
    ok Apache2::ServerUtil::exists_config_define('MODPERL2');
    ok ! Apache2::ServerUtil::exists_config_define('FOO');

    t_debug('registering method FOO');
    ok $r->server->method_register('FOO');

    server_root_relative_tests($r);

    eval { Apache2::ServerUtil::server_shutdown_cleanup_register(
        sub { Apache2::Const::OK });
       };
    my $sub = "server_shutdown_cleanup_register";
    ok t_cmp $@, qr/Can't run '$sub' after server startup/,
        "can't register server_shutdown cleanup after server startup";

    # on start we get 1, and immediate restart gives 2
    ok t_cmp Apache2::ServerUtil::restart_count, 2, "restart count";

    Apache2::Const::OK;
}


# 11 sub-tests
sub server_root_relative_tests {
    my $r = shift;

    my %pools = (
        '$r->pool'                                    =>
            $r->pool,
        '$r->connection->pool'                        =>
            $r->connection->pool,
        '$r->server->process->pool'                   =>
            $r->server->process->pool,
        '$r->server->process->pconf'                  =>
            $r->server->process->pconf,
        'Apache2::ServerUtil->server->process->pconf' =>
            Apache2::ServerUtil->server->process->pconf,
        'APR::Pool->new'                              =>
            APR::Pool->new,
    );

    # syntax - an object or pool is required
    t_debug("Apache2::ServerUtil::server_root_relative() died");
    eval { my $dir = Apache2::ServerUtil::server_root_relative() };
    t_debug("\$\@: $@");
    ok $@;

    foreach my $p (keys %pools) {
        # we will leak memory here when calling the function with a
        # pool whose life is longer than of $r, but it doesn't matter
        # for the test
        ok t_filepath_cmp(
            canonpath(Apache2::ServerUtil::server_root_relative($pools{$p},
                                                               'conf')),
            catfile($serverroot, 'conf'),
            "Apache2::ServerUtil:::server_root_relative($p, 'conf')");
    }

    # syntax - unrecognized objects don't segfault
    {
        my $obj = bless {}, 'Apache2::Foo';
        eval { Apache2::ServerUtil::server_root_relative($obj, 'conf') };

        ok t_cmp($@,
                 qr/p is not of type APR::Pool/,
                 "Apache2::ServerUtil::server_root_relative(\$obj, 'conf')");
    }

    # no file argument gives ServerRoot
    {
        my $server_root_relative =
            Apache2::ServerUtil::server_root_relative($r->pool);

        ok t_filepath_cmp(canonpath($server_root_relative),
                          canonpath($serverroot),
                          'server_root_relative($pool)');

        # Apache2::ServerUtil::server_root is also the ServerRoot constant
        ok t_filepath_cmp(canonpath(Apache2::ServerUtil::server_root),
                          canonpath($server_root_relative),
                          'Apache2::ServerUtil::server_root');

    }

    {
        # absolute paths should resolve to themselves
        my $dir1 = Apache2::ServerUtil::server_root_relative($r->pool, 'logs');
        my $dir2 = Apache2::ServerUtil::server_root_relative($r->pool, $dir1);

        ok t_filepath_cmp($dir1, $dir2, "absolute path");
    }
}

1;

__END__
