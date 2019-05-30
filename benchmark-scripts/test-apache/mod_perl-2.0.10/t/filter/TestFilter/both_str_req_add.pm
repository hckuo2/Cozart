# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::both_str_req_add;

# insert an input filter which lowers the case of the data
# insert an output filter which strips spaces

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Filter ();

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);

sub header_parser {
    my $r = shift;
    # test adding by coderef
    $r->add_input_filter(\&in_filter);
    # test adding by sub's name
    $r->add_output_filter("out_filter");

    # test adding anon sub
    $r->add_output_filter(sub {
        my $filter = shift;

        while ($filter->read(my $buffer, 1024)) {
            $buffer .= "end";
            $filter->print($buffer);
        }

        return Apache2::Const::OK;
    });

    return Apache2::Const::DECLINED;
}

sub in_filter {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        $filter->print(lc $buffer);
    }

    Apache2::Const::OK;
}

sub out_filter {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        $buffer =~ s/\s+//g;
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
    PerlModule TestFilter::both_str_req_add
    <Location /TestFilter__both_str_req_add>
        SetHandler modperl
        PerlHeaderParserHandler TestFilter::both_str_req_add::header_parser
        PerlResponseHandler     TestFilter::both_str_req_add
    </Location>
</NoAutoConfig>




