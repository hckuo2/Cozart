# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_str_req_eos;

# here we test how EOS is passed from one streaming filter to another,
# making sure that it's not lost

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);

my $prefix = 'PREFIX_';
my $suffix = '_SUFFIX';

sub add_prefix {
    my $filter = shift;

    #warn "add_prefix called\n";

    unless ($filter->ctx) {
        $filter->print($prefix);
        $filter->ctx(1);
    }

    while ($filter->read(my $buffer, 1024)){
        #warn "add_prefix read: [$buffer]\n";
        $filter->print($buffer);
    }

    Apache2::Const::OK;
}

sub add_suffix {
    my $filter = shift;

    #warn "add_suffix called\n";

    while ($filter->read(my $buffer, 1024)){
        #warn "add_suffix read: [$buffer]\n";
        $filter->print($buffer);
    }

    if ($filter->seen_eos) {
        $filter->print($suffix);
        $filter->ctx(1);
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
    PerlModule TestFilter::out_str_req_eos
    <Location /TestFilter__out_str_req_eos>
        SetHandler modperl
        PerlResponseHandler     TestFilter::out_str_req_eos
        PerlOutputFilterHandler TestFilter::out_str_req_eos::add_prefix
        PerlOutputFilterHandler TestFilter::out_str_req_eos::add_suffix
    </Location>
</NoAutoConfig>




