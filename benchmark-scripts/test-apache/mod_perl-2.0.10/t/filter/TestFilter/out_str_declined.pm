# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_str_declined;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Filter ();

use Apache2::Const -compile => qw(OK DECLINED);

use constant READ_SIZE  => 1024;

# make sure that if the input filter returns DECLINED without
# reading/printing data the data flow is not broken
sub decline {
      my $filter = shift;

      my $ctx = $filter->ctx;
      $ctx->{invoked}++;
      $filter->ctx($ctx);

      # can't use $f->seen_eos, since we don't read the data, so
      # we have to set the note on each invocation
      $filter->r->notes->set(invoked => $ctx->{invoked});
      #warn "decline    filter was invoked $ctx->{invoked} times\n";

      return Apache2::Const::DECLINED;
}

# this filter ignores all the data that comes through, though on the
# last invocation it prints how many times the filter 'decline' was called
# which it could count by itself, but we want to test that
# 'return Apache2::Const::DECLINED' works properly in output filters
sub black_hole {
    my $filter = shift;

    my $ctx = $filter->ctx;
    $ctx->{invoked}++;
    $filter->ctx($ctx);
    #warn "black_hole filter was invoked $ctx->{invoked} times\n";

    while ($filter->read(my $data, READ_SIZE)) {
        #warn "black_hole data: $data\n";
        # let the data fall between the chairs
    }

    if ($filter->seen_eos) {
        my $invoked = $filter->r->notes->get('invoked') || 0;
        $filter->print($invoked);
    }

    return Apache2::Const::OK;
}

sub response {
    my $r = shift;

    # just to make sure that print() won't flush, or we would get the
    # count wrong
    local $| = 0;

    $r->content_type('text/plain');
    for (1..10) {
        $r->print("a"); # this buffers the data
        $r->rflush;     # this sends the data in the buffer + flush bucket
    }

    Apache2::Const::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule              TestFilter::out_str_declined
PerlResponseHandler     TestFilter::out_str_declined::response
PerlOutputFilterHandler TestFilter::out_str_declined::decline
PerlOutputFilterHandler TestFilter::out_str_declined::black_hole
