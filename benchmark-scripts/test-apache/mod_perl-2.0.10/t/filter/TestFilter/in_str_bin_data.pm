# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_str_bin_data;

# test that $r->print and $f->print handle binary data correctly
# (e.g. doesn't truncate on "\0" if there is more data after it)

use strict;
use warnings FATAL => 'all';

use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::Filter ();

use Apache::TestTrace;

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);

sub pass_through {
    my $f = shift;

    while ($f->read(my $buffer, 1024)) {
        debug "read: " . length ($buffer) . "b [$buffer]";
        $f->print($buffer);
    }

    return Apache2::Const::OK;
}

sub handler {
    my $r = shift;

    if ($r->method_number == Apache2::Const::M_POST) {
        my $data = TestCommon::Utils::read_post($r);
        my $length = length $data;
        debug "pass through $length bytes of $data\n";
        $r->print($data);
    }

    Apache2::Const::OK;
}

1;
__END__
<NoAutoConfig>
PerlModule TestFilter::in_str_bin_data
<Location /TestFilter__in_str_bin_data_filter>
    PerlInputFilterHandler TestFilter::in_str_bin_data::pass_through
    SetHandler modperl
    PerlResponseHandler TestFilter::in_str_bin_data
</Location>
<Location /TestFilter__in_str_bin_data>
    SetHandler modperl
    PerlResponseHandler TestFilter::in_str_bin_data
</Location>
</NoAutoConfig>

