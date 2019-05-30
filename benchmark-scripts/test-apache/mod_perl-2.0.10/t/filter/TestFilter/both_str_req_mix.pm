# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::both_str_req_mix;

# this is an elaborated test, where we mix several apache and mod_perl
# filters, both input and output and verifying that they can work
# together, preserving the order when the filters are of the same
# priority

# in this test the client, the client sends a compressed body,
# 'DEFLATE' deflates it, then mod_perl filter 'transparent' filter
# passes data through as-is. The following 'in_adjust' mod_perl filter
# removes the string 'INPUT' from incoming data. The response handler
# simply passes the data through. Next output filters get to work:
# 'out_adjust_before_ssi' fixups the data to a valid SSI directive, by
# removing the string 'OUTPUT' from the outgoing data, then the
# 'INCLUDES' filter fetches the virtual file, and finally
# 'out_adjust_after_ssi' fixes the file contents returned by SSI, by
# removing the string 'REMOVE'
#
# Here is a visual representation of the transformations:
#
#       =>  <network in>
#
#  compressed data
#
#       =>  DEFLATE
#
#  <!--#include INPUTvirtual="/includes/OUTPUTclear.shtml" -->
#
#       =>  transparent
#
#  <!--#include INPUTvirtual="/includes/OUTPUTclear.shtml" -->
#
#       =>  in_adjust
#
#  <!--#include virtual="/includes/OUTPUTclear.shtml" -->
#
#       <=> response handler
#
#  <!--#include virtual="/includes/OUTPUTclear.shtml" -->
#
#       <=  out_adjust_before_ssi
#
#  <!--#include virtual="/includes/clear.shtml" -->
#
#       <=  out_adjust_before_ssi
#
#  <!--#include virtual="/includes/clear.shtml" -->
#
#       <=  INCLUDES
#
#  This is a REMOVEclear text
#
#       <=  out_adjust_after_ssi
#
#  This is a clear text
#
#       <=  DEFLATE
#
#  compressed data
#
#       <=  <network out>


use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();

use Apache::TestTrace;

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);

use constant DEBUG => 1;

sub transparent {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)){
        debug "transparent buffer: $buffer";
        $buffer =~ s/foo//;
        $filter->print($buffer);
    }

    $filter->print("");

    Apache2::Const::OK;
}

sub in_adjust              { adjust("INPUT",  @_)}
sub out_adjust_before_ssi  { adjust("OUTPUT", @_)}
sub out_adjust_after_ssi   { adjust("REMOVE", @_)}

sub adjust {
    my ($string, $filter) = @_;
    my $sig = "adjust($string):";

    while ($filter->read(my $buffer, 1024)){
        debug "$sig before: $buffer";
        $buffer =~ s/$string//;
        debug "$sig after: $buffer";
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
    PerlModule TestFilter::both_str_req_mix
    <Location /TestFilter__both_str_req_mix>
        Options +Includes

        # DEFLATE has a higher priority (AP_FTYPE_CONTENT_SET=20) than
        # mod_perl request filters (AP_FTYPE_RESOURCE=10), so it's going
        # to filter input first no matter how we insert other mod_perl
        # filters. (mod_perl connection filter handlers have an even
        # higher priority (AP_FTYPE_PROTOCOL = 30), see
        # include/util_filter.h for those definitions).
        #
        # PerlSetInputFilter is only useful for preserving the
        # insertion order of filters with the same priority
        SetInputFilter     DEFLATE
        #PerlInputFilterHandler TestCommon::FilterDebug::snoop_request
        PerlInputFilterHandler TestFilter::both_str_req_mix::in_adjust
        PerlInputFilterHandler TestFilter::both_str_req_mix::transparent

        # here INCLUDES and adjust are both of the same priority
        # (AP_FTYPE_RESOURCE), so PerlSetOutputFilter
        PerlOutputFilterHandler TestFilter::both_str_req_mix::out_adjust_before_ssi
        PerlSetOutputFilter INCLUDES
        PerlOutputFilterHandler TestFilter::both_str_req_mix::out_adjust_after_ssi
        #PerlOutputFilterHandler TestCommon::FilterDebug::snoop_request
        PerlSetOutputFilter DEFLATE

        SetHandler modperl
        PerlResponseHandler     TestFilter::both_str_req_mix
    </Location>
</NoAutoConfig>




