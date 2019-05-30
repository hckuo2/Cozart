# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestExit::FromPerlModule;

use strict;
use warnings FATAL => qw(all);

use Apache2::ServerRec;
use Apache2::ServerUtil;
use Apache2::Log;
use Apache2::Const -compile => qw(OK);

sub exit_handler {
    my ($p, $s) = @_;

    $s->log->info("Child process pid=$$ is exiting - server push");

    Apache2::Const::OK;
}

Apache2::ServerUtil->server->push_handlers(PerlChildExitHandler => \&exit_handler);

1;
