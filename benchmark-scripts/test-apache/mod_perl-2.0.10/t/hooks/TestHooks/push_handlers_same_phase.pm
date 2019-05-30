# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::push_handlers_same_phase;

# test that we
# - can push handlers into the same phase that is currently running
# - cannot switch 'perl-script' to 'modperl' and vice versa once
#   inside the response phase

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK DECLINED);

sub handler {
    my $r = shift;

    my $counter = $r->notes->get('counter') || 0;
    $r->notes->set(counter => $counter+1);

    $r->push_handlers(PerlResponseHandler => \&real_response);

    return Apache2::Const::DECLINED;
}

sub real_response {
    my $r = shift;

    plan $r, tests => 3;

    # test that we don't rerun all the handlers again (it should no
    # longer happen as we don't allow switching 'perl-script' <=>
    # 'modperl' on the go, but test anyway)
    my $counter = $r->notes->get('counter') || 0;
    ok t_cmp($counter, 1,
             __PACKAGE__ . "::handler must have been called only once");

    my @handlers = @{ $r->get_handlers('PerlResponseHandler') || []};
    ok t_cmp(scalar(@handlers),
             2,
             "there should be 2 response handlers");

    # once running inside the response phase it shouldn't be possible
    # to switch from 'perl-script' to 'modperl' and vice versa
    eval { $r->handler("perl-script") };
    ok t_cmp($@, qr/Can't switch from/,
             "can't switch from 'perl-script' to 'modperl' inside " .
             "the response phase");

    return Apache2::Const::OK;
}

1;
__END__
<NoAutoConfig>
<Location /TestHooks__push_handlers_same_phase>
    SetHandler modperl
    PerlResponseHandler TestHooks::push_handlers_same_phase
</Location>
</NoAutoConfig>
