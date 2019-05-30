# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestProtocol::echo_bbs;

# this test is similar to TestProtocol::echo_filter, but performs the
# manipulations on the buckets inside the connection handler, rather
# then using filter

# it also demonstrates how to use a single bucket bridade to do all
# the manipulation

use strict;
use warnings FATAL => 'all';

use Apache2::Connection ();
use APR::Socket ();
use APR::Bucket ();
use APR::Brigade ();
use APR::Error ();

use Apache::TestTrace;

use Apache2::Const -compile => qw(OK MODE_GETLINE);
use APR::Const    -compile => qw(SUCCESS SO_NONBLOCK);
use APR::Status ();

sub handler {
    my $c = shift;

    # starting from Apache 2.0.49 several platforms require you to set
    # the socket to a blocking IO mode
    $c->client_socket->opt_set(APR::Const::SO_NONBLOCK, 0);

    my $bb = APR::Brigade->new($c->pool, $c->bucket_alloc);

    while (1) {
        debug "asking new line";
        my $rc = $c->input_filters->get_brigade($bb, Apache2::Const::MODE_GETLINE);
        last if APR::Status::is_EOF($rc);
        die APR::Error::strerror($rc) unless $rc == APR::Const::SUCCESS;

        for (my $b = $bb->first; $b; $b = $bb->next($b)) {

            last if $b->is_eos;

            debug "processing new line";

            if ($b->read(my $data)) {
                last if $data =~ /^[\r\n]+$/;
                my $nb = APR::Bucket->new($bb->bucket_alloc, uc $data);
                # head->...->$nb->$b ->...->tail
                # XXX: the next 3 lines could be replaced with a
                # wrapper function $b->replace($nb);
                $b->insert_before($nb);
                $b->delete;
                $b = $nb;
            }
        }

        $c->output_filters->fflush($bb);
    }

    $bb->destroy;

    Apache2::Const::OK;
}

1;
