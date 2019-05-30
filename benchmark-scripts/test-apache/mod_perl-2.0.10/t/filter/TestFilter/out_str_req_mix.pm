# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_str_req_mix;

# in this test we verify that we can preserve the mixed order of
# modperl and non-modperl filters using the PerlSetOutputFilter
# directive, instead of SetOutputFilter for non-modperl filters.
#
# response handler prints a mangled SSI directive:
#     <!--#include virtual="/includes/REMOVEclear.shtml" -->
# (which it receives via POST from the client)
#
# adjust() filter is configured to be called first and it removes the
# string 'REMOVE' from the response handler's output, so that SSI will
# find the fixed resource specification:
#     <!--#include virtual="/includes/clear.shtml" -->
#
# the INCLUDES filter, which is configured to be next on the stack
# (mod_include) processes the directive and returns the contents of
# file "/includes/clear.shtml", which is:
#    This is a REMOVEclear text
#
# finally the second mod_perl filter (which happens to be the same
# adjust() filter, but to all purposes it's a separate filter)
# configured to run after the INCLUDES filter fixes the data sent by
# the INCLUDES filter to be:
#    This is a clear text
#
# and this is what the client is expecting to receive
#
# WARNING: notice that the adjust() filter assumes that it'll receive
# the word REMOVE in a single bucket, which is good enough for the
# test because we control all the used filters and normally Apache
# core filters won't split short data into several buckets.  However
# filter developers shouldn't make any assumptions, since any data can
# be split by any of the upstream filters.

use strict;
use warnings FATAL => 'all';

use Apache2::Filter ();

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);

sub adjust {
    my $filter = shift;

    #warn "adjust called\n";

    while ($filter->read(my $buffer, 1024)){
        $buffer =~ s/REMOVE//;
        $filter->print($buffer);
    }

    Apache2::Const::OK;
}

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache2::Const::M_POST) {
        $r->print(TestCommon::Utils::read_post($r));
    }

    return Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
    PerlModule TestFilter::out_str_req_mix
    <Location /TestFilter__out_str_req_mix>
        Options +Includes
        PerlOutputFilterHandler TestFilter::out_str_req_mix::adjust
        PerlSetOutputFilter INCLUDES
        PerlOutputFilterHandler TestFilter::out_str_req_mix::adjust
        SetHandler modperl
        PerlResponseHandler     TestFilter::out_str_req_mix
    </Location>
</NoAutoConfig>




