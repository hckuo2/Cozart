# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_bbs_body;

use strict;
use warnings FATAL => 'all';

use base qw(Apache2::Filter); #so we inherit MODIFY_CODE_ATTRIBUTES

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use APR::Brigade ();
use APR::Bucket ();

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);
use APR::Const -compile => ':common';

sub handler : FilterRequestHandler {
    my ($filter, $bb, $mode, $block, $readbytes) = @_;

    $filter->next->get_brigade($bb, $mode, $block, $readbytes);

    for (my $b = $bb->first; $b; $b = $bb->next($b)) {

        last if $b->is_eos;

        if ($b->read(my $data)) {
            #warn"[$data]\n";
            my $nb = APR::Bucket->new($bb->bucket_alloc, scalar reverse $data);
            $b->insert_before($nb);
            $b->delete;
            $b = $nb;
        }
    }

    Apache2::Const::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache2::Const::M_POST) {
        my $data = TestCommon::Utils::read_post($r);
        $r->puts($data);
    }
    else {
        $r->puts("1..3\nok 1\n");
    }

    Apache2::Const::OK;
}

1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_bbs_body
PerlResponseHandler TestFilter::in_bbs_body::response
