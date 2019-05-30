# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCommon::FilterDebug;

use strict;
use warnings FATAL => 'all';

use base qw(Apache2::Filter);
use APR::Brigade ();
use APR::Bucket ();
use APR::BucketType ();

use Apache2::Const -compile => qw(OK DECLINED);
use APR::Const -compile => ':common';

# to use these functions add any or all of these filter handlers
# PerlModule              TestCommon::FilterDebug
# PerlInputFilterHandler  TestCommon::FilterDebug::snoop_request
# PerlInputFilterHandler  TestCommon::FilterDebug::snoop_connection
# PerlOutputFilterHandler TestCommon::FilterDebug::snoop_request
# PerlOutputFilterHandler TestCommon::FilterDebug::snoop_connection
#

sub snoop_connection : FilterConnectionHandler { snoop("connection", @_) }
sub snoop_request    : FilterRequestHandler    { snoop("request",    @_) }

sub snoop {
    my $type = shift;
    my ($filter, $bb, $mode, $block, $readbytes) = @_; # filter args

    # $mode, $block, $readbytes are passed only for input filters
    my $stream = defined $mode ? "input" : "output";

    # read the data and pass-through the bucket brigades unchanged
    if (defined $mode) {
        # input filter
        my $rv = $filter->next->get_brigade($bb, $mode, $block, $readbytes);
        return $rv unless $rv == APR::Const::SUCCESS;
        bb_dump($type, $stream, $bb);
    }
    else {
        # output filter
        bb_dump($type, $stream, $bb);
        my $rv = $filter->next->pass_brigade($bb);
        return $rv unless $rv == APR::Const::SUCCESS;
    }
    #if ($bb->is_empty) {
    #    return -1;
    #}

    return Apache2::Const::OK;
}

sub bb_dump {
    my ($type, $stream, $bb) = @_;

    my @data;
    for (my $b = $bb->first; $b; $b = $bb->next($b)) {
        $b->read(my $bdata);
        push @data, $b->type->name, $bdata;
    }

    # send the sniffed info to STDERR so not to interfere with normal
    # output
    my $direction = $stream eq 'output' ? ">>>" : "<<<";
    print STDERR "\n$direction $type $stream filter\n";

    unless (@data) {
        print STDERR "  No buckets\n";
        return;
    }

    my $c = 1;
    while (my ($btype, $data) = splice @data, 0, 2) {
        print STDERR "    o bucket $c: $btype\n";
        print STDERR "[$data]\n";
        $c++;
    }
}

1;

__END__
