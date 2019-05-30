# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::in_out_filters;

# testing: $r->input_filters and $r->output_filters
# it's possible to read a POST data and send a response body w/o using
# $r->read/$r->print

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestUtil ();

use APR::Brigade ();
use APR::Bucket ();
use Apache2::Filter ();

use Apache2::Const -compile => qw(OK M_POST DECLINED MODE_READBYTES);
use APR::Const    -compile => qw(SUCCESS BLOCK_READ);

use constant IOBUFSIZE => 8192;

sub handler {
    my $r = shift;

    return Apache2::Const::DECLINED unless $r->method_number == Apache2::Const::M_POST;

    $r->content_type("text/plain");

    my $data = read_request_body($r);
    send_response_body($r, lc($data));

    Apache2::Const::OK;
}

sub send_response_body {
    my ($r, $data) = @_;

    my $bb = APR::Brigade->new($r->pool,
                               $r->connection->bucket_alloc);

    my $b = APR::Bucket->new($r->connection->bucket_alloc, $data);
    $bb->insert_tail($b);
    $r->output_filters->fflush($bb);
    $bb->destroy;
}

sub read_request_body {
    my $r = shift;

    my $bb = APR::Brigade->new($r->pool,
                               $r->connection->bucket_alloc);

    my $data = '';
    my $seen_eos = 0;
    my $count = 0;
    do {
        $r->input_filters->get_brigade($bb, Apache2::Const::MODE_READBYTES,
                                       APR::Const::BLOCK_READ, IOBUFSIZE);

        $count++;

        for (my $b = $bb->first; $b; $b = $bb->next($b)) {
            if ($b->is_eos) {
                $seen_eos++;
                last;
            }

            if ($b->read(my $buf)) {
                $data .= $buf;
            }

            $b->delete;
        }

    } while (!$seen_eos);

    $bb->destroy;

    return $data;
}

1;
__END__
