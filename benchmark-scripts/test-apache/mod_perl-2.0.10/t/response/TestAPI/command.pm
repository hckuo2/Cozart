# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::command;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::Command ();
use Apache2::Module ();

use Apache2::Const -compile => qw(OK ITERATE OR_ALL);

sub handler {
    my $r = shift;

    plan $r, tests => 6;

    my $mod_perl_module = Apache2::Module::find_linked_module('mod_perl.c');

    ok $mod_perl_module;

    my $cmd = $mod_perl_module->cmds;

    ok defined $cmd;

    ok UNIVERSAL::isa($cmd, 'Apache2::Command');

    while ($cmd) {
        if ($cmd->name eq 'PerlResponseHandler') {
            ok t_cmp($cmd->args_how, Apache2::Const::ITERATE, 'args_how');
            ok t_cmp($cmd->errmsg, qr/Subroutine name/, 'errmsg');
            ok t_cmp($cmd->req_override, Apache2::Const::OR_ALL, 'req_override');
            last;
        }
        $cmd = $cmd->next;
    }

    Apache2::Const::OK;
}

1;
