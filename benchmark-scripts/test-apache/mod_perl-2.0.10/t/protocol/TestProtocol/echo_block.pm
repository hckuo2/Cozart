# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestProtocol::echo_block;

# this test reads from/writes to the socket doing blocking IO
#
# see TestProtocol::echo_timeout for how to do the same with
# nonblocking IO but using the timeout

use strict;
use warnings FATAL => 'all';

use Apache2::Connection ();
use APR::Socket ();

use TestCommon::Utils;

use Apache2::Const -compile => 'OK';
use APR::Const    -compile => qw(SO_NONBLOCK);

use constant BUFF_LEN => 1024;

sub handler {
    my Apache2::Connection $c = shift;
    my APR::Socket $socket = $c->client_socket;

    # starting from Apache 2.0.49 several platforms require you to set
    # the socket to a blocking IO mode
    my $nonblocking = $socket->opt_get(APR::Const::SO_NONBLOCK);
    if ($nonblocking) {
        $socket->opt_set(APR::Const::SO_NONBLOCK, 0);

        # test that we really *are* in the blocking mode
        !$socket->opt_get(APR::Const::SO_NONBLOCK)
            or die "failed to set blocking mode";
    }

    while ($socket->recv(my $buffer, BUFF_LEN)) {

        die "recv() has returned untainted data:"
            unless TestCommon::Utils::is_tainted($buffer);

        $socket->send($buffer);
    }

    Apache2::Const::OK;
}

1;
