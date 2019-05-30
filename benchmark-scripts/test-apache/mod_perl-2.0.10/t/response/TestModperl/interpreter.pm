# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::interpreter;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::MPM ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $is_threaded=Apache2::MPM->is_threaded;

    plan $r, tests => $is_threaded?17:5, need
        need_threads,
        {"perl >= 5.8.1 is required (this is $])" => ($] >= 5.008001)};

    require ModPerl::Interpreter;
    require ModPerl::InterpPool;
    require ModPerl::TiPool;
    require ModPerl::TiPoolConfig;

    my $interp = ModPerl::Interpreter->current;

    ok t_cmp(ref($interp), 'ModPerl::Interpreter',
             'interp is a ModPerl::Interpreter');

    ok t_cmp($$interp==${ModPerl::Interpreter::current()}, !!1,
             'ModPerl::Interpreter->current == ModPerl::Interpreter::current');

    my $mip = $interp->mip;

    ok t_cmp(ref($mip), 'ModPerl::InterpPool',
             'interp->mip is a ModPerl::InterpPool');

    ok t_cmp(${$mip->server}==${$r->server}, !!1,
             'mip->server == r->server');

    ok t_cmp(ref($mip->parent), 'ModPerl::Interpreter',
             'mip->parent is a ModPerl::Interpreter');

    if($is_threaded) {
        ok t_cmp($interp->perl!=0, !!1, 'interp->perl');
        ok t_cmp($interp->num_requests>0, !!1, 'interp->num_requests');
        ok t_cmp($interp->refcnt>0, !!1, 'interp->refcnt');

        my $tipool = $mip->tipool;

        ok t_cmp(ref($tipool), 'ModPerl::TiPool',
                 'mip->tipool is a ModPerl::TiPool');

        ok t_cmp($tipool->in_use!=0, !!1, 'tipool->in_use');

        ok t_cmp($tipool->size!=0, !!1, 'tipool->size');

        my $tipcfg = $tipool->cfg;

        ok t_cmp(ref($tipcfg), 'ModPerl::TiPoolConfig',
                 'tipool->cfg is a ModPerl::TiPoolConfig');

        ok t_cmp($tipcfg->start!=0, !!1, 'tipcfg->start');

        ok t_cmp($tipcfg->min_spare!=0, !!1, 'tipcfg->min_spare');

        ok t_cmp($tipcfg->max_spare!=0, !!1, 'tipcfg->max_spare');

        ok t_cmp($tipcfg->max!=0, !!1, 'tipcfg->max');

        ok t_cmp($tipcfg->max_requests!=0, !!1, 'tipcfg->max_requests');
    }

    Apache2::Const::OK;
}

1;
__END__
