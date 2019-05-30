# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_str_declined;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Filter ();

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK DECLINED M_POST);

# make sure that if the input filter returns DECLINED without
# reading/printing data the data flow is not broken
sub handler {
      my $filter = shift;

      my $ctx = $filter->ctx;
      $ctx->{invoked}++;
      $filter->ctx($ctx);

      # can't use $f->seen_eos, since we don't read the data, so
      # we have to set the note on each invocation
      $filter->r->notes->set(invoked => $ctx->{invoked});
      #warn "filter was invoked $ctx->{invoked} times\n";

      return Apache2::Const::DECLINED;
}

sub response {
    my $r = shift;

    plan $r, tests => 2;

    $r->content_type('text/plain');

    if ($r->method_number == Apache2::Const::M_POST) {
        # consume the data so the input filter is invoked
        my $data = TestCommon::Utils::read_post($r);
        ok t_cmp(length $data, 20000, "the request body received ok");
    }

    # ~20k of input makes it four bucket brigades:
    #    - 2 full bucket brigades of 8k
    #    - 1 half full brigade ~4k
    #    - 1 bucket brigade with EOS bucket
    # however different Apache versions may send extra bb or split
    # data differently so we can't rely on the exact count
    my $invoked = $r->notes->get('invoked') || 0;
    ok $invoked > 1;

    Apache2::Const::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_str_declined
PerlResponseHandler TestFilter::in_str_declined::response

