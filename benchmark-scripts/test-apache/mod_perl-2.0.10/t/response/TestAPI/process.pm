# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::process;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestRec ();
use Apache2::ServerRec ();
use Apache2::Process ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 4;

    my $s = $r->server;
    my $proc = $s->process;
    ok t_cmp(1, $proc->isa('Apache2::Process'), "isa('Apache2::Process')");

    my $global_pool = $proc->pool;
    ok t_cmp(1, $global_pool->isa('APR::Pool'), "pglob isa('APR::Pool')");

    my $pconf = $proc->pconf;
    ok t_cmp(1, $pconf->isa('APR::Pool'), "pconf isa('APR::Pool')");

    my $proc_name = $proc->short_name;
    t_debug($proc_name);
    ok $proc_name;

    Apache2::Const::OK;
}

1;

__END__
