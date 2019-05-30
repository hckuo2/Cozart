# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_str_declined_read;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Filter ();

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK DECLINED M_POST);

# a filter must not return DECLINED after calling $r->read, since the
# latter already fetches the bucket brigade in which case it's up to
# the user to complete reading it and send it out
# thefore this filter must fail
sub handler {
      my $filter = shift;

      # this causes a fetch of bb
      $filter->read(my $buffer, 10);

      return Apache2::Const::DECLINED;
}

sub response {
    my $r = shift;

    plan $r, tests => 1;

    $r->content_type('text/plain');

    if ($r->method_number == Apache2::Const::M_POST) {
        # this should fail, because of the failing filter
        eval { TestCommon::Utils::read_post($r) };
        ok $@;
    }

    Apache2::Const::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_str_declined_read
PerlResponseHandler TestFilter::in_str_declined_read::response

