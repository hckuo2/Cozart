# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_str_sandwich;

# this test verifies whether the filter can pre-insert data (using
# context) and post-insert data (using the seen_eos flag)

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);

sub handler {
    my $filter = shift;

    my $ctx = $filter->ctx;

    unless ($ctx) {
        $filter->print("HEADER\n");
        $filter->ctx(1);
    }

    while ($filter->read(my $buffer, 1024)) {
        #warn "FILTER READ: $buffer\n";
        $filter->print($buffer);
    }

    if ($filter->seen_eos) {
        $filter->print("TAIL\n");
    }

    return Apache2::Const::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache2::Const::M_POST) {
        my $data = TestCommon::Utils::read_post($r);
        #warn "HANDLER READ: $data\n";
        $r->print($data);
    }

    return Apache2::Const::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_str_sandwich
PerlResponseHandler TestFilter::in_str_sandwich::response
