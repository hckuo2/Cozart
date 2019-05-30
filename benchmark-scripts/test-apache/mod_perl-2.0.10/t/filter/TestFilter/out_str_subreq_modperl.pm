# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_str_subreq_modperl;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();

use Apache2::Filter ();

use Apache2::Const -compile => qw(OK);

# include the contents of a subrequest
# in the filter, a la mod_include's
# <!--#include virtual="/subrequest" -->

sub include {

    my $filter = shift;

    unless ($filter->ctx) {
        # don't forget to remove the C-L header
        $filter->r->headers_out->unset('Content-Length');

        $filter->ctx(1);
    }

    while ($filter->read(my $buffer, 1024)){

        if ($buffer eq "<tag>\n") {
            my $sub = $filter->r->lookup_uri('/modperl_subrequest');
            my $rc = $sub->run;
        }
        else {
           # send all other data along unaltered
           $filter->print($buffer);
        }

    }

    # add our own at the end
    if ($filter->seen_eos) {
        $filter->print("filter\n");
        $filter->ctx(1);
    }

    return Apache2::Const::OK;
}

sub subrequest {

    my $r = shift;

    $r->content_type('text/plain');
    $r->print("modperl subrequest\n");

    return Apache2::Const::OK;
}

sub response {

    my $r = shift;

    $r->content_type('text/plain');

    $r->print("content\n");
    $r->rflush;
    $r->print("<tag>\n");
    $r->rflush;
    $r->print("more content\n");

    Apache2::Const::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule              TestFilter::out_str_subreq_modperl
PerlResponseHandler     TestFilter::out_str_subreq_modperl::response
PerlOutputFilterHandler TestFilter::out_str_subreq_modperl::include

<Location /modperl_subrequest>
  SetHandler modperl
  PerlResponseHandler   TestFilter::out_str_subreq_modperl::subrequest
</Location>
