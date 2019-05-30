# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_bbs_inject_header;

# this filter demonstrates two things:
# 1. how to write a filter that will work only on HTTP headers
# 2. how to inject extra HTTP headers
#
# the first task is simple for non-keepalive connections -- as soon as
# a bucket which matches /^[\r\n]+$/ is read we can store that event
# in the filter context and simply 'return Apache2::Const::DECLINED on the
# future invocation, so not to slow things.
#
# it becomes much trickier with keepalive connection, since Apache
# provides no API to tell you whether a new request is coming in. We
# use $c->keepalives to figure out when a new request is coming in, by
# comparing the previously stored keepalives count, which gets
# incremented by Apache when the HTTP response headers are generated.
#
#
# the second task is a bit trickier, as the headers_in core httpd
# filter is picky and it wants each header to arrive in a separate
# bucket, and moreover this bucket needs to be in its own brigade.
# so this test arranges for this to happen.
#
# the test shows how to push headers at the end of all headers
# and in the middle, whichever way you prefer.

use strict;
use warnings FATAL => 'all';

use base qw(Apache2::Filter);

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Connection ();
use APR::Brigade ();
use APR::Bucket ();
use APR::Table ();

use Apache::TestTrace;

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK DECLINED CONN_KEEPALIVE);
use APR::Const    -compile => ':common';

my $header1_key = 'X-My-Protocol';
my $header1_val = 'POST-IT';

my %headers = (
    'X-Extra-Header2' => 'Value 2',
    'X-Extra-Header3' => 'Value 3',
);

my $request_body = "This body shouldn't be seen by the filter";

# returns 1 if a bucket with a header was inserted to the $bb's tail,
# otherwise returns 0 (i.e. if there are no buckets to insert)
sub inject_header_bucket {
    my ($bb, $ctx) = @_;

    return 0 unless @{ $ctx->{buckets} };

    my $b = shift @{ $ctx->{buckets} };
    $bb->insert_tail($b);

    if (1) {
        # extra debug, wasting cycles
        $b->read(my $data);
        debug "injected header: [$data]";
    }
    else {
        debug "injected header";
    }

    # next filter invocations will bring the request body if any
    if ($ctx->{seen_body_separator} && !@{ $ctx->{buckets} }) {
        $ctx->{done_with_headers}   = 1;
        $ctx->{seen_body_separator} = 0;
    }

    return 1;
}

sub context {
    my $filter = shift;

    my $ctx = $filter->ctx;
    my $c   = $filter->c;
    unless ($ctx) {
        debug "filter context init";
        $ctx = {
            buckets             => [],
            done_with_headers   => 0,
            seen_body_separator => 0,
            keepalives          => $c->keepalives,
        };

        # since we are going to manipulate the reference stored in
        # ctx, it's enough to store it only once, we will get the same
        # reference in the following invocations of that filter
        $filter->ctx($ctx);
        return $ctx;
    }

    if ($c->keepalive == Apache2::Const::CONN_KEEPALIVE &&
        $ctx->{done_with_headers} &&
        $c->keepalives > $ctx->{keepalives}) {

        debug "a new request resetting the input filter state";

        $ctx->{buckets}             = [];
        $ctx->{done_with_headers}   = 0;
        $ctx->{seen_body_separator} = 0;
        $ctx->{keepalives} = $c->keepalives;
    }

    return $ctx;

}

sub handler : FilterConnectionHandler {
    my ($filter, $bb, $mode, $block, $readbytes) = @_;

    debug join '', "-" x 20 , " input filter called -", "-" x 20;

    my $ctx = context($filter);
    my $c = $filter->c;

    # reset the filter state, we start a new request
    if ($c->keepalive == Apache2::Const::CONN_KEEPALIVE &&
        $ctx->{done_with_headers} && $c->notes->get('reset_request')) {
        debug "a new request resetting the input filter state";
        $c->notes->set('reset_request' => 0);
        $ctx->{buckets} = [];
        $ctx->{seen_body_separator} = 0;
        $ctx->{done_with_headers} = 0;
    }

    # handling the HTTP request body
    if ($ctx->{done_with_headers}) {
        # XXX: when the bug in httpd filter will be fixed all the
        # code in this branch will be replaced with:
        #   $filter->remove;
        #   return Apache2::Const::DECLINED;
        # at the moment (2.0.48) it doesn't work
        # so meanwhile tell the mod_perl filter core to pass-through
        # the brigade unmodified
        debug "passing the body through unmodified";
        return Apache2::Const::DECLINED;
    }

    # any custom HTTP header buckets to inject?
    return Apache2::Const::OK if inject_header_bucket($bb, $ctx);

    # normal HTTP headers processing
    my $ctx_bb = APR::Brigade->new($c->pool, $c->bucket_alloc);
    my $rv = $filter->next->get_brigade($ctx_bb, $mode, $block, $readbytes);
    return $rv unless $rv == APR::Const::SUCCESS;

    while (!$ctx_bb->is_empty) {
        my $b = $ctx_bb->first;

        if ($b->is_eos) {
            debug "EOS!!!";
            $b->remove;
            $bb->insert_tail($b);
            last;
        }

        $b->read(my $data);
        # remove must happen after read, since it may cause split and
        # some new buckets inserted behind - if remove called too
        # early, those buckets will be lost
        $b->remove;
        debug "filter read:\n[$data]";

        # check that we really work only on the headers
        die "This filter should not ever receive the request body, " .
            "but HTTP headers" if ($data||'') eq $request_body;

        if ($data and $data =~ /^POST/) {
            # demonstrate how to add a header while processing other headers
            my $header = "$header1_key: $header1_val\n";
            push @{ $ctx->{buckets} }, APR::Bucket->new($c->bucket_alloc, $header);
            debug "queued header [$header]";
        }
        elsif ($data =~ /^[\r\n]+$/) {
            # normally the body will start coming in the next call to
            # get_brigade, so if your filter only wants to work with
            # the headers, it can decline all other invocations if that
            # flag is set. However since in this test we need to send
            # a few extra bucket brigades, we will turn another flag
            # 'done_with_headers' when 'seen_body_separator' is on and
            # all headers were sent out
            debug "END of original HTTP Headers";
            $ctx->{seen_body_separator}++;

            # we hit the headers and body separator, which is a good
            # time to add extra headers:
            for my $key (keys %headers) {
                my $header = "$key: $headers{$key}\n";
                push @{ $ctx->{buckets} }, APR::Bucket->new($c->bucket_alloc, $header);
                debug "queued header [$header]";
            }

            # but at the same time we must ensure that the
            # the separator header will be sent as a last header
            # so we send one newly added header and push the separator
            # to the end of the queue
            # XXX: this is broken: the bucket must be set-aside before
            # it can be stashed away (missing $b->setaside wrapper)
            push @{ $ctx->{buckets} }, $b;
            debug "queued header [$data]";
            inject_header_bucket($bb, $ctx);
            next; # inject_header_bucket already called insert_tail
            # notice that if we didn't inject any headers, this will
            # still work ok, as inject_header_bucket will send the
            # separator header which we just pushed to its queue
        }
        else {
            # fall through
        }

        $bb->insert_tail($b);
    }

    return Apache2::Const::OK;
}

sub response {
    my $r = shift;

    # propogate the input headers and the input back to the client
    # as we need to do the validations on the client side
    $r->headers_out->set($header1_key =>
                         $r->headers_in->get($header1_key)||'');

    for my $key (sort keys %headers) {
        $r->headers_out->set($key => $r->headers_in->get($key)||'');
    }

    my $data = TestCommon::Utils::read_post($r);
    $r->print($data);

    Apache2::Const::OK;
}

1;
__END__
<NoAutoConfig>
<VirtualHost TestFilter::in_bbs_inject_header>
  PerlModule TestFilter::in_bbs_inject_header
  PerlInputFilterHandler TestFilter::in_bbs_inject_header
  <Location /TestFilter__in_bbs_inject_header>
     SetHandler modperl
     PerlResponseHandler TestFilter::in_bbs_inject_header::response
  </Location>
</VirtualHost>
</NoAutoConfig>
