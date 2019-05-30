# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_str_ctx;

# this is the same test as TestFilter::context, but uses the streaming
# API

use strict;
use warnings;# FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use base qw(Apache2::Filter);

use Apache2::Const -compile => qw(OK M_POST);
use APR::Const -compile => ':common';

use constant BLOCK_SIZE => 5003;
use constant READ_SIZE  => 1024;

sub handler {
    my $filter = shift;

    my $ctx = $filter->ctx;
    my $data = exists $ctx->{data} ? $ctx->{data} : '';
    $ctx->{invoked}++;

    while ($filter->read(my $bdata, READ_SIZE)) {
        $data .= $bdata;
        my $len = length $data;

        my $blocks = 0;
        if ($len >= BLOCK_SIZE) {
            $blocks = int($len / BLOCK_SIZE);
            $len = $len % BLOCK_SIZE;
            $data = substr $data, $blocks*BLOCK_SIZE, $len;
            $ctx->{blocks} += $blocks;
        }
        if ($blocks) {
            $filter->print("#" x $blocks);
        }
    }

    if ($filter->seen_eos) {
        # flush the remaining data and add a statistics signature
        $filter->print("$data\n") if $data;
        my $sig = join "\n", "received $ctx->{blocks} complete blocks",
            "filter invoked $ctx->{invoked} times\n";
        $filter->print($sig);
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

    # just to make sure that print() flushes, or we would get the
    # count wrong
    local $| = 1;

    # make sure that
    # - we send big enough data so it won't fit into one buffer
    # - use chunk size which doesn't nicely fit into a buffer size, so
    #   we have something to store in the context between filter calls

    my $blocks = 33;
    my $block_size = BLOCK_SIZE + 1;
    my $block = "x" x $block_size;
    for (1..$blocks) {
        $r->print($block);
        $r->rflush; # so the filter reads a chunk at a time
    }

    return Apache2::Const::OK;
}

1;
__DATA__

SetHandler modperl
PerlModule          TestFilter::out_str_ctx
PerlResponseHandler TestFilter::out_str_ctx::response

