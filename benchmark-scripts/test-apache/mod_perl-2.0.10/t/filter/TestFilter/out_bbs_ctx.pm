# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_bbs_ctx;

# this is the same test as TestFilter::context_stream, but uses the
# bucket brigade API

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use APR::Brigade ();
use APR::Bucket ();
use APR::BucketType ();

use base qw(Apache2::Filter);

use Apache::TestTrace;

use Apache2::Const -compile => qw(OK M_POST);
use APR::Const -compile => ':common';

use constant BLOCK_SIZE => 5003;

sub handler {
    my ($filter, $bb) = @_;

    debug "filter got called";

    my $c = $filter->c;
    my $ba = $c->bucket_alloc;
    my $bb_ctx = APR::Brigade->new($c->pool, $ba);

    my $ctx = $filter->ctx;
    $ctx->{invoked}++;

    my $data = exists $ctx->{data} ? $ctx->{data} : '';

    while (my $b = $bb->first) {

        if ($b->is_eos) {
            debug "got EOS";
            # flush the remainings and send a stats signature
            $bb_ctx->insert_tail(APR::Bucket->new($ba, "$data\n")) if $data;
            my $sig = join "\n", "received $ctx->{blocks} complete blocks",
                "filter invoked $ctx->{invoked} times\n";
            $bb_ctx->insert_tail(APR::Bucket->new($ba, $sig));
            $b->remove;
            $bb_ctx->insert_tail($b);
            last;
        }

        if ($b->read(my $bdata)) {
            debug "got data";
            $b->delete;
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
                my $nb = APR::Bucket->new($ba, "#" x $blocks);
                $bb_ctx->insert_tail($nb);
            }
        }
        else {
            debug "got bucket with no data: type: " . $b->type->name;
            $b->remove;
            $bb_ctx->insert_tail($b);
        }

    }

    $ctx->{data} = $data;
    $filter->ctx($ctx);

    my $rv = $filter->next->pass_brigade($bb_ctx);
    return $rv unless $rv == APR::Const::SUCCESS;

    return Apache2::Const::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    # just to make sure that print() won't flush, or we would get the
    # count wrong
    local $| = 0;

    # make sure that:
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
PerlModule          TestFilter::out_bbs_ctx
PerlResponseHandler TestFilter::out_bbs_ctx::response

