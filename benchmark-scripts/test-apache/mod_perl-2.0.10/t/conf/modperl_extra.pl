# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
##########################################################
### IMPORTANT: only things that must be run absolutely ###
### during the config phase should be in this file     ###
##########################################################
#
# On the 2nd pass, during server-internal restart, none of the code
# running from this file (config phase) will be able to log any STDERR
# messages. This is because Apache redirects STDERR to /dev/null until
# the open_logs phase. That means that any of the code fails, the
# error message will be lost (but it should have failed on the 1st
# pass, when STDERR goes to the console and any error messages are
# properly logged). Therefore avoid putting any code here (unless
# there is no other way) and instead put all the code to be run at the
# server startup into post_config_startup.pl. when the latter is run,
# STDERR is sent to $ErrorLog.
#

use strict;
use warnings FATAL => 'all';

die '$ENV{MOD_PERL} not set!' unless $ENV{MOD_PERL};
die '$ENV{MOD_PERL_API_VERSION} not set!'
    unless $ENV{MOD_PERL_API_VERSION} == 2;

use File::Spec::Functions qw(canonpath catdir);

use Apache2::ServerUtil ();
use Apache2::ServerRec ();
use Apache2::Process ();
use Apache2::Log ();

use Apache2::Const -compile => ':common';

reorg_INC();

startup_info();

test_add_config();

test_add_version_component();

test_hooks_startup();

test_modperl_env();



### only subs below this line ###

# need to run from config phase, since we want to adjust @INC as early
# as possible
sub reorg_INC {
    # after Apache2 has pushed blib and core dirs including Apache2 on
    # top reorg @INC to have first devel libs, then blib libs, and
    # only then perl core libs
    my $pool = Apache2::ServerUtil->server->process->pool;
    my $project_root = canonpath
        Apache2::ServerUtil::server_root_relative($pool, "..");
    my (@a, @b, @c);
    for (@INC) {
        if (m|^\Q$project_root\E|) {
            m|blib| ? push @b, $_ : push @a, $_;
        }
        else {
            push @c, $_;
        }
    }
    @INC = (@a, @b, @c);
}

# this can be run from post_config_startup.pl, but then it'll do the
# logging twice, so in this case it's actually good to have this code
# run during config phase, so it's logged only once (even though it's
# run the second time, but STDERR == /dev/null)
sub startup_info {
    my $ap_mods  = scalar grep { /^Apache2/ } keys %INC;
    my $apr_mods = scalar grep { /^APR/    } keys %INC;

    Apache2::Log->info("$ap_mods Apache2:: modules loaded");
    Apache2::ServerRec->log->info("$apr_mods APR:: modules loaded");

    my $server = Apache2::ServerUtil->server;
    my $vhosts = 0;
    for (my $s = $server->next; $s; $s = $s->next) {
        $vhosts++;
    }

    $server->log->info("base server + $vhosts vhosts ready to run tests");
}

# need to run from config phase, since it changes server config
sub test_add_config {
    # testing $s->add_config()
    my $conf = <<'EOC';
# must use PerlModule here to check for segfaults
PerlModule Apache::TestHandler
<Location /apache/add_config>
  SetHandler perl-script
  PerlResponseHandler Apache::TestHandler::ok1
</Location>
EOC
    Apache2::ServerUtil->server->add_config([split /\n/, $conf]);

    # test a directive that triggers an early startup, so we get an
    # attempt to use perl's mip early
    Apache2::ServerUtil->server->add_config(['<Perl >', '1;', '</Perl>']);
}

# need to run from config phase, since it registers PerlPostConfigHandler
sub test_add_version_component {
    Apache2::ServerUtil->server->push_handlers(
        PerlPostConfigHandler => \&add_my_version);

    sub add_my_version {
        my ($conf_pool, $log_pool, $temp_pool, $s) = @_;
        $s->add_version_component("world domination series/2.0");
        return Apache2::Const::OK;
    }
}

# cleanup files for TestHooks::startup which can't be done from the
# test itself because the files are created at the server startup and
# the test needing these files may run more than once (t/SMOKE)
#
# we need to run it at config phase since we need to cleanup before
# the open_logs phase
sub test_hooks_startup {
    require Apache::Test;
    my $dir = catdir Apache::Test::vars('documentroot'), qw(hooks startup);
    for (<$dir/*>) {
        my $file = ($_ =~ /(.*(?:open_logs|post_config)-\d+)/);
        unlink $file;
    }
}

sub test_modperl_env {
    # see t/response/TestModperl/env.pm
    $ENV{MODPERL_EXTRA_PL} = __FILE__;
}

1;
