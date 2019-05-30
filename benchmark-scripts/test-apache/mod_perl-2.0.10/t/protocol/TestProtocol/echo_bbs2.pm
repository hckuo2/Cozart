# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestProtocol::echo_bbs2;

# similar to TestProtocol::echo_bbs but here re-using one bucket
# brigade for input and output, using flatten to slurp all the data in
# the bucket brigade, and cleanup to get rid of the old buckets

use strict;
use warnings FATAL => 'all';

use Apache2::Connection ();
use APR::Socket ();
use APR::Bucket ();
use APR::Brigade ();
use APR::Error ();

use Apache2::Const -compile => qw(OK MODE_GETLINE);
use APR::Const    -compile => qw(SUCCESS SO_NONBLOCK);
use APR::Status ();

sub handler {
    my $c = shift;

    # starting from Apache 2.0.49 several platforms require you to set
    # the socket to a blocking IO mode
    $c->client_socket->opt_set(APR::Const::SO_NONBLOCK, 0);

    my $bb_in  = APR::Brigade->new($c->pool, $c->bucket_alloc);
    my $bb_out = APR::Brigade->new($c->pool, $c->bucket_alloc);

    my $last = 0;
    while (1) {
        my $rc = $c->input_filters->get_brigade($bb_in,
                                                Apache2::Const::MODE_GETLINE);
        last if APR::Status::is_EOF($rc);
        die APR::Error::strerror($rc) unless $rc == APR::Const::SUCCESS;

        next unless $bb_in->flatten(my $data);
        #warn "read: [$data]\n";
        last if $data =~ /^[\r\n]+$/;

        # transform data here
        my $bucket = APR::Bucket->new($bb_in->bucket_alloc, uc $data);
        $bb_out->insert_tail($bucket);

        $c->output_filters->fflush($bb_out);

        $bb_in->cleanup;
        $bb_out->cleanup;
    }

    # XXX: add DESTROY and remove explicit calls
    $bb_in->destroy;
    $bb_out->destroy;

    Apache2::Const::OK;
}

1;
