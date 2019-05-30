# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_str_buffer;

# in this test we want to buffer the data, modify the length of the
# response, set the c-l header and make sure that the client sees the
# right thing
#
# notice that a bucket brigades based filter must be used. The streaming
# API lets FLUSH buckets through which causes an early flush of HTTP
# response headers

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use APR::Table ();
use APR::Bucket ();
use APR::Brigade ();

use TestCommon::Utils ();

use base qw(Apache2::Filter);

use Apache2::Const -compile => qw(OK M_POST);
use APR::Const     -compile => ':common';

sub flatten_bb {
    my ($bb) = shift;

    my $seen_eos = 0;

    my @data;
    for (my $b = $bb->first; $b; $b = $bb->next($b)) {
        $seen_eos++, last if $b->is_eos;
        $b->read(my $bdata);
        push @data, $bdata;
    }
    return (join('', @data), $seen_eos);
}

sub handler {
    my ($filter, $bb) = @_;

    my $ctx = $filter->ctx;

    # no need to unset the C-L header, since this filter makes sure to
    # correct it before any headers go out.
    #unless ($ctx) {
    #    $filter->r->headers_out->unset('Content-Length');
    #}

    my $data = exists $ctx->{data} ? $ctx->{data} : '';
    $ctx->{invoked}++;
    my ($bdata, $seen_eos) = flatten_bb($bb);
    $bdata =~ s/-//g;
    $data .= $bdata if $bdata;

    if ($seen_eos) {
        my $len = length $data;
        $filter->r->headers_out->set('Content-Length', $len);
        $filter->print($data) if $data;
    }
    else {
        # store context for all but the last invocation
        $ctx->{data} = $data;
        $filter->ctx($ctx);
    }

    return Apache2::Const::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    my $data = '';
    if ($r->method_number == Apache2::Const::M_POST) {
        $data = TestCommon::Utils::read_post($r);
        $r->headers_out->set('Content-Length' => length $data);
    }

    for my $chunk (split /0/, $data) {
        $r->print($chunk);
        $r->rflush; # so the filter reads a chunk at a time
    }

    return Apache2::Const::OK;
}

1;
__DATA__

SetHandler modperl
PerlModule          TestFilter::out_str_buffer
PerlResponseHandler TestFilter::out_str_buffer::response

