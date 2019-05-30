# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::setupenv;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK DECLINED);

sub handler {

    my $r = shift;

    # how many different URIs will be hit?
    my $requests = $r->args;

    # $requests locations with 7 tests each
    plan $r, tests => $requests * 7;

    return Apache2::Const::OK;
}

sub env {

    my $r = shift;

    Apache::Test::init_test_pm($r);  # tie STDOUT

    (my $value) = $r->uri =~ /TestModperl__setupenv_(\w+)/;

    ok t_cmp($ENV{REMOTE_ADDR},
             Apache::Test::vars('remote_addr'),
             'found REMOTE_ADDR in %ENV');

    ok t_cmp($ENV{SRV_SUBPROCESS},
             'server',
             'found subprocess_env table entry SRV_SUBPROCESS in %ENV');

    ok t_cmp($ENV{DIR_SUBPROCESS},
             $value,
             'found subprocess_env table entry DIR_SUBPROCESS in %ENV');

    ok t_cmp($ENV{DIR_SETENV},
             $value,
             'found per-directory SetEnv entry in %ENV');

    ok t_cmp($ENV{SRV_SETENV},
             'server',
             'found per-server SetEnv entry in %ENV');

    # PerlSetEnv always set
    ok t_cmp($ENV{DIR_PERLSETENV},
             $value,
             'found per-directory PerlSetEnv entry in %ENV');

    ok t_cmp($ENV{SRV_PERLSETENV},
             'server',
             'found per-server PerlSetEnv entry in %ENV');

    return Apache2::Const::OK;
}

sub noenv {

    my $r = shift;

    Apache::Test::init_test_pm($r);  # tie STDOUT

    (my $value) = $r->uri =~ /TestModperl__setupenv_(\w+)/;

    ok t_cmp($ENV{REMOTE_ADDR},
             undef,
             'REMOTE_ADDR not found in %ENV');

    ok t_cmp($ENV{SRV_SUBPROCESS},
             undef,
             'subprocess_env table entry SRV_SUBPROCESS not found in %ENV');

    ok t_cmp($ENV{DIR_SUBPROCESS},
             undef,
             'subprocess_env table entry DIR_SUBPROCESS not found in %ENV');

    ok t_cmp($ENV{DIR_SETENV},
             undef,
             'per-directory SetEnv entry not found in %ENV');

    ok t_cmp($ENV{SRV_SETENV},
             undef,
             'per-server SetEnv entry not found in %ENV');

    # PerlSetEnv always set
    ok t_cmp($ENV{DIR_PERLSETENV},
             $value,
             'found per-directory PerlSetEnv entry in %ENV');

    ok t_cmp($ENV{SRV_PERLSETENV},
             'server',
             'found per-server PerlSetEnv entry in %ENV');

    return Apache2::Const::OK;
}

sub someenv {

    my $r = shift;

    Apache::Test::init_test_pm($r);  # tie STDOUT

    (my $value) = $r->uri =~ /TestModperl__setupenv_(\w+)/;

    ok t_cmp($ENV{REMOTE_ADDR},
             Apache::Test::vars('remote_addr'),
             'found REMOTE_ADDR in %ENV');

    # set before void call
    ok t_cmp($ENV{SRV_SUBPROCESS},
             'server',
             'found subprocess_env table entry one in %ENV');

    ok t_cmp($ENV{DIR_SUBPROCESS},
             undef,
             'subprocess_env table entry DIR_SUBPROCESS not found in %ENV');

    ok t_cmp($ENV{DIR_SETENV},
             undef,
             'per-directory SetEnv entry not found in %ENV');

    ok t_cmp($ENV{SRV_SETENV},
             undef,
             'per-server SetEnv entry not found in %ENV');

    # PerlSetEnv always set
    ok t_cmp($ENV{DIR_PERLSETENV},
             $value,
             'found per-directory PerlSetEnv entry in %ENV');

    ok t_cmp($ENV{SRV_PERLSETENV},
             'server',
             'found per-server PerlSetEnv entry in %ENV');

    return Apache2::Const::OK;
}

sub subenv_void {

    shift->subprocess_env;

    return Apache2::Const::OK;
}

sub subenv_one {

    shift->subprocess_env->set(SRV_SUBPROCESS => 'server');

    return Apache2::Const::OK;
}

sub subenv_two {

    my $r = shift;

    (my $value) = $r->uri =~ /TestModperl__setupenv_(\w+)/;

    $r->subprocess_env->set(DIR_SUBPROCESS => $value);

    return Apache2::Const::OK;
}

1;
__DATA__
# create a separate virtual host so we can use
# keepalives - a per-connection interpreter is
# the only way to make sure that we can plan in
# one request and test in subsequent tests
<NoAutoConfig>
<VirtualHost TestModperl::setupenv>

    KeepAlive On

#    <IfDefine PERL_USEITHREADS>
#        PerlInterpScope connection
#    </Ifdefine>

    PerlModule TestModperl::setupenv

    PerlPostReadRequestHandler TestModperl::setupenv::subenv_one

    # SetEnv is affected by +SetupEnv
    <IfModule mod_env.c>
        SetEnv SRV_SETENV server
    </IfModule>

    # PerlSetEnv is not affected by +SetupEnv or -SetupEnv
    # it is entirely separate and always set if configured
    PerlSetEnv SRV_PERLSETENV server

    # plan
    <Location /TestModperl__setupenv>
        SetHandler modperl
        PerlResponseHandler TestModperl::setupenv
    </Location>

    # default modperl handler
    # %ENV should not contain standard CGI variables
    # or entries from the subprocess_env table
    <Location /TestModperl__setupenv_mpdefault>
        SetHandler modperl
        PerlResponseHandler TestModperl::setupenv::noenv

        PerlFixupHandler TestModperl::setupenv::subenv_two
        <IfModule mod_env.c>
            SetEnv DIR_SETENV mpdefault
        </IfModule>
        PerlSetEnv DIR_PERLSETENV mpdefault
    </Location>

    # modperl handler + SetupEnv
    # %ENV should contain CGI variables as well as
    # anything put into the subprocess_env table
    <Location /TestModperl__setupenv_mpsetup>
        SetHandler modperl
        PerlResponseHandler TestModperl::setupenv::env

        PerlOptions +SetupEnv

        PerlFixupHandler TestModperl::setupenv::subenv_two

        <IfModule mod_env.c>
            SetEnv DIR_SETENV mpsetup
        </IfModule>
        PerlSetEnv DIR_PERLSETENV mpsetup
    </Location>

    # $r->subprocess_env in a void context with no args
    # should do the same as +SetupEnv wrt CGI variables
    # and entries already in the subprocess_env table
    # but subprocess_env entries that appear later will
    # not show up in %ENV
    <Location /TestModperl__setupenv_mpvoid>
        SetHandler modperl
        PerlResponseHandler TestModperl::setupenv::someenv

        PerlHeaderParserHandler TestModperl::setupenv::subenv_void
        PerlFixupHandler TestModperl::setupenv::subenv_two

        <IfModule mod_env.c>
            SetEnv DIR_SETENV mpvoid
        </IfModule>
        PerlSetEnv DIR_PERLSETENV mpvoid
    </Location>

    # +SetupEnv should always populate %ENV fully prior
    # to running the content handler (regardless of when
    # $r->subprocess_env() was called) to ensure that
    # %ENV is an accurate representation of the
    # subprocess_env table
    <Location /TestModperl__setupenv_mpsetupvoid>
        SetHandler modperl
        PerlResponseHandler TestModperl::setupenv::env

        PerlOptions +SetupEnv

        PerlHeaderParserHandler TestModperl::setupenv::subenv_void
        PerlFixupHandler TestModperl::setupenv::subenv_two

        <IfModule mod_env.c>
            SetEnv DIR_SETENV mpsetupvoid
        </IfModule>
        PerlSetEnv DIR_PERLSETENV mpsetupvoid
    </Location>

    # default perl-script handler is equivalent to +SetupEnv
    # CGI variables and subprocess_env entries will be in %ENV
    <Location /TestModperl__setupenv_psdefault>
        SetHandler perl-script
        PerlResponseHandler TestModperl::setupenv::env

        PerlFixupHandler TestModperl::setupenv::subenv_two

        <IfModule mod_env.c>
            SetEnv DIR_SETENV psdefault
        </IfModule>
        PerlSetEnv DIR_PERLSETENV psdefault
    </Location>

    # -SetupEnv should not put CGI variables or subprocess_env
    # entries in %ENV
    <Location /TestModperl__setupenv_psnosetup>
        SetHandler perl-script
        PerlResponseHandler TestModperl::setupenv::noenv

        PerlOptions -SetupEnv

        PerlFixupHandler TestModperl::setupenv::subenv_two

        <IfModule mod_env.c>
            SetEnv DIR_SETENV psnosetup
        </IfModule>
        PerlSetEnv DIR_PERLSETENV psnosetup
    </Location>

    # +SetupEnv should always populate %ENV fully prior
    # to running the content handler (regardless of when
    # $r->subprocess_env() was called) to ensure that
    # %ENV is an accurate representation of the
    # subprocess_env table
    <Location /TestModperl__setupenv_psvoid>
        SetHandler perl-script
        PerlResponseHandler TestModperl::setupenv::env

        PerlHeaderParserHandler TestModperl::setupenv::subenv_void
        PerlFixupHandler TestModperl::setupenv::subenv_two

        <IfModule mod_env.c>
            SetEnv DIR_SETENV psvoid
        </IfModule>
        PerlSetEnv DIR_PERLSETENV psvoid
    </Location>

    # equivalent to modperl handler with $r->subprocess_env() -
    # CGI variables are there, but not subprocess_env entries
    # that are populated after the void call
    <Location /TestModperl__setupenv_psnosetupvoid>
        SetHandler perl-script
        PerlResponseHandler TestModperl::setupenv::someenv

        PerlOptions -SetupEnv

        PerlHeaderParserHandler TestModperl::setupenv::subenv_void
        PerlFixupHandler TestModperl::setupenv::subenv_two

        <IfModule mod_env.c>
            SetEnv DIR_SETENV psnosetupvoid
        </IfModule>
        PerlSetEnv DIR_PERLSETENV psnosetupvoid
    </Location>
</VirtualHost>
</NoAutoConfig>
