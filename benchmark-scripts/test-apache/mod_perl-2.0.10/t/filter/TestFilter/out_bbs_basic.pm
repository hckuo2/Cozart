# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_bbs_basic;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();
use APR::Brigade ();
use APR::Bucket ();
use APR::BucketType ();

use Apache2::Const -compile => 'OK';

#XXX: Not implemented yet, required by Test.pm
sub Apache::TestToString::PRINTF {}

sub handler {
    my ($filter, $bb) = @_;

    unless ($filter->ctx) {

        Apache::TestToString->start;

        plan tests => 4;

        my $ba = $filter->r->connection->bucket_alloc;

        #should only have 1 bucket from the response() below
        for (my $b = $bb->first; $b; $b = $bb->next($b)) {
            ok $b->type->name;
            ok $b->length == 2;
            $b->read(my $data);
            ok (defined $data and $data eq 'ok');
        }

        my $tests = Apache::TestToString->finish;

        my $brigade = APR::Brigade->new($filter->r->pool, $ba);
        my $b = APR::Bucket->new($ba, $tests);

        $brigade->insert_tail($b);

        my $ok = $brigade->first->type->name =~ /mod_perl/ ? 4 : 0;
        $brigade->insert_tail(APR::Bucket->new($ba, "ok $ok\n"));

        $brigade->insert_tail(APR::Bucket::eos_create($ba));

        $filter->next->pass_brigade($brigade);

        $filter->ctx(1); # flag that we have run this already
    }

    Apache2::Const::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');
    $r->puts("ok");

    0;
}

1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::out_bbs_basic
PerlResponseHandler TestFilter::out_bbs_basic::response
