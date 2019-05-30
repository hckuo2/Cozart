# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_bbs_consume;

# this test consumes a chunk of input, then consumes and throws away
# the rest of the data, finally returns to the caller that initial
# chunk. This all happens during a single filter invocation. Even
# though there about 6-7 incoming data brigades.

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();
use Apache2::Connection ();
use APR::Brigade ();
use APR::Bucket ();

use Apache::TestTrace;

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);

use constant READ_SIZE => 26;

sub handler {
    my ($filter, $bb, $mode, $block, $readbytes) = @_;
    my $ba = $filter->r->connection->bucket_alloc;
    my $seen_eos = 0;
    my $satisfied = 0;
    my $buffer = '';
    debug_sub "filter called";

    until ($satisfied) {
        my $tbb = APR::Brigade->new($filter->r->pool, $ba);
        $filter->next->get_brigade($tbb, $mode, $block, READ_SIZE);
        debug "asking for a bb of " . READ_SIZE . " bytes\n";
        my $data;
        ($data, $seen_eos) = bb_data_n_eos($tbb);
        $tbb->destroy;
        $buffer .= $data;
        length($buffer) < READ_SIZE ? redo : $satisfied++;
    }

    # consume all the remaining input
    do {
        my $tbb = APR::Brigade->new($filter->r->pool, $ba);
        $filter->next->get_brigade($tbb, $mode, $block, $readbytes);
        debug "discarding the next bb";
        $seen_eos = bb_data_n_eos($tbb, 1); # only scan
        $tbb->destroy;
    } while (!$seen_eos);

    if ($seen_eos) {
        # flush the remainder
        $bb->insert_tail(APR::Bucket->new($ba, $buffer));
        $bb->insert_tail(APR::Bucket::eos_create($ba));
        debug "seen eos, sending: " . length($buffer) . " bytes";
    }
    else {
        die "Something is wrong, this filter should have been called only once";
    }

    return Apache2::Const::OK;
}

# if $scan_only is true, don't read the data, just look for eos
sub bb_data_n_eos {
    my ($bb, $scan_only) = @_;

    if ($scan_only) {
        for (my $b = $bb->first; $b; $b = $bb->next($b)) {
            return 1 if $b->is_eos;
        }
        return 0;
    }

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
        $r->print($data);
    }

    return Apache2::Const::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_bbs_consume
PerlResponseHandler TestFilter::in_bbs_consume::response
