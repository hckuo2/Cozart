# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_str_eval;

# at some point there was a problem when eval {} in a non-filter
# handler wasn't functioning when a filter was involved. the $@ value
# was getting lost when t_cmp was doing print of debug values. and a
# new invocation of a filter handler resets the value of $@.

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK DECLINED);

# dummy pass_through filter was good enough to trigger the problem
sub handler {
    return Apache2::Const::DECLINED;
}

sub response {
    my $r = shift;

    plan $r, tests => 1;
    # test that filters don't reset $@
    eval { i_do_not_exist_really_i_do_not() };
    # trigger the filter invocation, before using $@
    $r->print("# whatever");
    $r->rflush;
    ok t_cmp($@, qr/Undefined subroutine/, "some croak");

    return Apache2::Const::OK;
}

1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::out_str_eval
PerlResponseHandler TestFilter::out_str_eval::response

