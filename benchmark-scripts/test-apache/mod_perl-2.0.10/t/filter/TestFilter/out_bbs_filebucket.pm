# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_bbs_filebucket;

# testing how the filter handles file buckets

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter;
use Apache2::URI ();

use APR::Brigade ();
use APR::Bucket ();

use Apache::TestTrace;

use Apache2::Const -compile => qw(OK);
use APR::Const    -compile => qw(SUCCESS);

use constant BLOCK_SIZE => 5003;

sub handler {
    my ($filter, $bb) = @_;

    debug "FILTER INVOKED";

    my $cnt = 0;
    for (my $b = $bb->first; $b; $b = $bb->next($b)) {

        $cnt++;
        debug "reading bucket #$cnt";

        last if $b->is_eos;

        if (my $len = $b->read(my $data)) {
            my $nb = APR::Bucket->new($bb->bucket_alloc, uc $data);
            $b->insert_before($nb);
            $b->delete;
            $b = $nb;
        }
    }

    return $filter->next->pass_brigade($bb);
}

sub response {
    my $r = shift;

    debug "\n-------- new request ----------";

    $r->content_type('text/plain');

    my $file = $r->args;
    Apache2::URI::unescape_url($file);
    $r->sendfile($file);

    return Apache2::Const::OK;
}

1;
__DATA__
SetHandler modperl
PerlModule              TestFilter::out_bbs_filebucket
PerlResponseHandler     TestFilter::out_bbs_filebucket::response
PerlOutputFilterHandler TestFilter::out_bbs_filebucket::handler
