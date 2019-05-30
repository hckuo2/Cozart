# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_bbs_underrun;

# this test exercises the underrun filter concept. Sometimes filters
# need to read at least N bytes before they can apply their
# transformation. It's quite possible that reading one bucket brigade
# is not enough. But two or more are needed.
#
# When the filter realizes that it doesn't have enough data, it can
# stash the read data in the context, and wait for the next
# invocation, meanwhile it must return an empty bb to the filter that
# has called it. This is not efficient. Instead of returning an empty
# bb to a caller, the input filter can initiate the retrieval of extra
# bucket brigades, after one was received. Notice that this is
# absolutely transparent to any filters before or after the current
# filter.
#
# to see the filter at work, run it as:
# t/TEST -trace=debug -v filter/in_bbs_underrun
#
# and look in the error_log. You will see something like:
#
# ==> TestFilter::in_bbs_underrun::handler : filter called
# ==> asking for a bb
# ==> asking for a bb
# ==> asking for a bb
# ==> storing the remainder: 7611 bytes
# ==> TestFilter::in_bbs_underrun::handler : filter called
# ==> asking for a bb
# ==> asking for a bb
# ==> storing the remainder: 7222 bytes
# ==> TestFilter::in_bbs_underrun::handler : filter called
# ==> asking for a bb
# ==> seen eos, flushing the remaining: 8182 bytes
#
# it's clear from the log that the filter was invoked 3 times, however
# it has consumed 6 bucket brigades
#
# finally, we have to note that this is impossible to do with
# streaming filters, since they can only read data from one bucket
# brigade. So you must process bucket brigades.
#

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();

use Apache::TestTrace;

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);

use constant SIZE => 1024*16 + 5; # ~16k

sub handler {
    my ($filter, $bb, $mode, $block, $readbytes) = @_;
    my $ba = $filter->r->connection->bucket_alloc;
    my $ctx = $filter->ctx;
    my $buffer = defined $ctx ? $ctx : '';
    $ctx = '';  # reset
    my $seen_eos = 0;
    my $data;
    debug_sub "filter called";

    # fetch and consume bucket brigades untill we have at least SIZE
    # bytes to work with
    do {
        my $tbb = APR::Brigade->new($filter->r->pool, $ba);
        $filter->next->get_brigade($tbb, $mode, $block, $readbytes);
        debug "asking for a bb";
        ($data, $seen_eos) = flatten_bb($tbb);
        $tbb->destroy;
        $buffer .= $data;
    } while (!$seen_eos && length($buffer) < SIZE);

    # now create a bucket per chunk of SIZE size and put the remainder
    # in ctx
    for (split_buffer($buffer)) {
        if (length($_) == SIZE) {
            $bb->insert_tail(APR::Bucket->new($bb->bucket_alloc, $_));
        }
        else {
            $ctx .= $_;
        }
    }

    if ($seen_eos) {
        # flush the remainder
        $bb->insert_tail(APR::Bucket->new($bb->bucket_alloc, $ctx));
        $bb->insert_tail(APR::Bucket::eos_create($ba));
        debug "seen eos, flushing the remaining: " . length($ctx) . " bytes";
    }
    else {
        # will re-use the remainder on the next invocation
        $filter->ctx($ctx);
        debug "storing the remainder: " . length($ctx) . " bytes";
    }

    return Apache2::Const::OK;
}

# split in words of SIZE chars and a remainder
sub split_buffer {
    my $buffer = shift;
    if ($] < 5.007) {
        my @words = $buffer =~ /(.{@{[SIZE]}}|.+)/g;
        return @words;
    }
    else {
        # available only since 5.7.x+
        return unpack "(A" . SIZE . ")*", $buffer;
    }
}

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


sub response {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache2::Const::M_POST) {
        my $data = TestCommon::Utils::read_post($r);
        #warn "HANDLER READ: $data\n";
        my $length = length $data;
        $r->print("read $length chars");
    }

    return Apache2::Const::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_bbs_underrun
PerlResponseHandler TestFilter::in_bbs_underrun::response
PerlInputFilterHandler TestFilter::in_bbs_underrun::handler
#PerlInputFilterHandler TestCommon::FilterDebug::snoop_request
