# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_str_reverse;

# this filter tests how the data can be set-aside between filter
# invocations. here we collect a single line (which terminates with a
# new line) before we apply the reversing transformation.

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);

use constant BUFF_LEN => 2;
use constant signature => "Reversed by mod_perl 2.0\n";

sub handler {
    my $f = shift;
    #warn "called\n";

    my $leftover = $f->ctx;

    # We are about to change the length of the response body. Hence, we
    # have to adjust the content-length header.
    unless (defined $leftover) { # 1st invocation
	$f->r->headers_out->{'Content-Length'}+=length signature
	    if exists $f->r->headers_out->{'Content-Length'};
    }

    while ($f->read(my $buffer, BUFF_LEN)) {
        #warn "buffer: [$buffer]\n";
        $buffer = $leftover . $buffer if defined $leftover;
        $leftover = undef;
        while ($buffer =~ /([^\r\n]*)([\r\n]*)/g) {
            $leftover = $1, last unless $2;
            $f->print(scalar(reverse $1), $2);
        }
    }

    if ($f->seen_eos) {
        $f->print(scalar reverse $leftover) if defined $leftover;
        $f->print(signature);
    }
    else {
        $f->ctx($leftover) if defined $leftover;
    }

    return Apache2::Const::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    # unbuffer stdout, so we get the data split across several bbs
    local $_ = 1;
    if ($r->method_number == Apache2::Const::M_POST) {
        my $data = TestCommon::Utils::read_post($r);
        $r->print($_) for grep length $_, split /(.{5})/, $data;
    }

    return Apache2::Const::OK;
}

1;
__DATA__
<Base>
    PerlModule TestFilter::out_str_reverse
    <LocationMatch "/filter/reverse.txt">
        PerlOutputFilterHandler TestFilter::out_str_reverse
    </LocationMatch>
</Base>

SetHandler modperl
PerlResponseHandler TestFilter::out_str_reverse::response

