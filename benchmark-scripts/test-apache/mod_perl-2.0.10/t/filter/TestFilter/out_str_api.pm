# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_str_api;

# Test Apache2::FilterRec and Apache2::Filter accessors

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();
use Apache2::FilterRec ();

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use Apache2::Const -compile => 'OK';

my $response_data = "blah blah blah";

#XXX: else pp_untie complains:
#untie attempted while %d inner references still exist
sub Apache2::Filter::UNTIE {}
sub Apache2::Filter::PRINTF {}

sub handler {
    my $filter = shift;

    my $data = '';
    while ($filter->read(my $buffer, 1024)) {
        $data .= $buffer;
    }

    tie *STDOUT, $filter;

    plan tests => 8;

    ok t_cmp($data, $response_data, "response data");

    ok $filter->isa('Apache2::Filter');

    {
        my $frec = $filter->frec;

        ok $frec->isa('Apache2::FilterRec');
        ok t_cmp($frec->name, "modperl_request_output", '$frec->name');

        my $next = $filter->next;
        ok t_cmp($next->frec->name, "modperl_request_output",
                 '$filter->next->frec->name');

        $next = $next->next;
        # since we can't ensure that the next filter will be the same,
        # as it's not under control, just check that we get some name
        my $name = $next->frec->name;
        t_debug("next->next name: $name");
        ok $name;
    }

    my $r = $filter->r;

    ok $r->isa('Apache2::RequestRec');

    my $path = '/' . Apache::TestRequest::module2path(__PACKAGE__);
    ok t_cmp($r->uri, $path, "path");

    untie *STDOUT;

    # we have done the job
    $filter->remove;

    Apache2::Const::OK;
}

sub pass_through {
    return Apache2::Const::DECLINED;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');
    $r->puts($response_data);

    Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
PerlModule TestFilter::out_str_api
<Location /TestFilter__out_str_api>
    SetHandler modperl
    PerlResponseHandler TestFilter::out_str_api::response
    PerlOutputFilterHandler TestFilter::out_str_api
    PerlOutputFilterHandler TestFilter::out_str_api::pass_through
</Location>
</NoAutoConfig>
