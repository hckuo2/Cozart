# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::pod;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 4;

    ok t_cmp $r->dir_config->get('TestDirective__pod_hidden'),      undef;
    ok t_cmp $r->dir_config->get('TestDirective__pod_over_worked'), 'yes';
    ok t_cmp $r->dir_config->get('TestDirective__pod_cut_worked'),  'yes';

    #XXX: How to test that __END__ works proprely without cloberring all the other tests?
    ok t_cmp '__END__', '__END__';

    Apache2::Const::OK;
}

1;
