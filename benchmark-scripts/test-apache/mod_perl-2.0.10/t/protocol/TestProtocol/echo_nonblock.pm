# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestProtocol::echo_nonblock;

# this test reads from/writes to the socket doing nonblocking IO

use strict;
use warnings FATAL => 'all';

use Apache2::Connection ();
use APR::Socket ();
use APR::Error ();

use Apache::TestTrace;

use Apache2::Const -compile => 'OK';
use APR::Const    -compile => qw(SO_NONBLOCK SUCCESS POLLIN);
use APR::Status ();

use constant BUFF_LEN => 1024;

sub handler {
    my $c = shift;
    my $socket = $c->client_socket;

    $socket->opt_set(APR::Const::SO_NONBLOCK, 1);

    my $counter = 0;
    my $timeout = 0;
    while (1) {

        debug "counter: $counter";
        if ($counter == 1) {
            # this will certainly cause timeout
            $timeout = 0;
        } else {
            # Wait up to ten seconds for data to arrive.
            $timeout = 10_000_000;
        }
        $counter++;

        my $rc = $socket->poll($c->pool, $timeout, APR::Const::POLLIN);
        if ($rc == APR::Const::SUCCESS) {
            my $buf;
            my $len = eval { $socket->recv($buf, BUFF_LEN) };
            if ($@) {
                # rethrow
                die $@ unless ref $@ eq 'APR::Error'
                    && (APR::Status::is_ECONNABORTED($@) ||
                        APR::Status::is_ECONNRESET($@));
                # ECONNABORTED == 103
                # ECONNRESET   == 104
                # ECONNABORTED is not an application error
                # XXX: we don't really test that we always get this
                # condition, since it depends on the timing of the
                # client closing the socket. may be it'd be possible
                # to make sure that APR::Const::ECONNABORTED was received
                # when $counter == 2 if we have slept enough, but how
                # much is enough is unknown
                debug "caught '104: Connection reset by peer' error";
                last;
            }

            last unless $len;

            debug "sending: $buf";
            $socket->send($buf);
        }
        elsif (APR::Status::is_TIMEUP($rc)) {
            debug "timeout";
            $socket->send("TIMEUP\n");
        }
        else {
            die "poll error: $rc: " . APR::Error::strerror($rc);
        }
    }

    Apache2::Const::OK;
}

1;
