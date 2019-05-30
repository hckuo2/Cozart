# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::discard_rbody;

# test $r->discard_request_body when the input body wasn't read at
# all, read partially or completely.

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Connection ();
use Apache2::Filter ();
use APR::Brigade ();
use APR::Error ();

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK MODE_READBYTES);
use APR::Const    -compile => qw(SUCCESS BLOCK_READ);

use constant IOBUFSIZE => 8192;

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    my $test = $r->args;

    if ($test eq 'none') {
        # don't read the request body
    }
    elsif ($test eq 'partial') {
        # read some of request POSTed data (IOBUFSIZE bytes),
        # but not all of it
        my $filters = $r->input_filters();
        my $ba = $r->connection->bucket_alloc;
        my $bb = APR::Brigade->new($r->pool, $ba);
        $filters->get_brigade($bb, Apache2::Const::MODE_READBYTES,
                              APR::Const::BLOCK_READ, IOBUFSIZE);
    }
    elsif ($test eq 'all') {
        # consume all of the request body
        my $data = TestCommon::Utils::read_post($r);
        die "failed to consume all the data" unless length($data) == 100000;
    }

    # now get rid of the rest of the input data should work, no matter
    # how little or how much of the body was read
    my $rc = $r->discard_request_body;
    die APR::Error::strerror($rc) unless $rc == Apache2::Const::OK;

    $r->print($test);

    Apache2::Const::OK;
}

1;
