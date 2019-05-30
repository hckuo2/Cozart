# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::bucket;

# a mix of APR::Brigade, APR::Bucket abd APR::BucketType tests

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Brigade ();
use APR::Bucket ();
use APR::BucketType ();
use Apache2::Connection ();
use Apache2::RequestRec ();

use Apache2::Const -compile => 'OK';

use TestAPRlib::bucket;

sub handler {

    my $r = shift;

    plan $r, tests => 20 + TestAPRlib::bucket::num_of_tests();

    TestAPRlib::bucket::test();

    my $ba = $r->connection->bucket_alloc;

    # eos_create / type / length
    {
        my $b = APR::Bucket::eos_create($ba);
        my $type = $b->type;
        ok t_cmp($type->name, 'EOS', "eos_create");

        ok t_cmp($b->length, 0, "eos b->length");

        # buckets with no data to read should return an empty string
        my $rlen = $b->read(my $read);
        ok t_cmp($read, "", 'eos b->read/buffer');
        ok t_cmp($rlen, 0, 'eos b->read/len');
    }

    # flush_create
    {
        my $b = APR::Bucket::flush_create($ba);
        my $type = $b->type;
        ok t_cmp($type->name, 'FLUSH', "flush_create");

        ok t_cmp($b->length, 0, "flush b->length");
    }

    # insert_after / insert_before / is_eos / is_flush
    {
        my $d1 = APR::Bucket->new($ba, "d1");
        my $d2 = APR::Bucket->new($ba, "d2");
        my $f1 = APR::Bucket::flush_create($ba);
        my $f2 = APR::Bucket::flush_create($ba);
        my $e1 = APR::Bucket::eos_create($ba);

        ### create a chain of buckets
        my $bb = APR::Brigade->new($r->pool, $ba);

                                 # head->tail
        $bb->insert_head(  $d1); # head->d1->tail
        $d1->insert_after( $d2); # head->d1->d2->tail
        $d2->insert_before($f1); # head->d1->f1->d2->tail
        $d2->insert_after( $f2); # head->d1->f1->d2->f2->tail
        $bb->insert_tail(  $e1); # head->d1->f1->d2->f2->e1->tail

        ### now test
        my $b = $bb->first;
        $b->read(my $read);
        ok t_cmp($read, "d1", "d1 bucket");

        $b = $bb->next($b);
        t_debug("is_flush");
        ok $b->is_flush;

        $b = $bb->next($b);
        $b->read($read);
        ok t_cmp($read, "d2", "d2 bucket");

        $b = $bb->last();
        t_debug("is_eos");
        ok $b->is_eos;

        $b = $bb->prev($b);
        t_debug("is_flush");
        ok $b->is_flush;

        t_debug("not empty");
        ok !$bb->is_empty;

        # delete all buckets from bb and test that it's empty
        while (!$bb->is_empty) {
            my $b = $bb->first;
            $b->delete;
        }

        t_debug("empty");
        ok $bb->is_empty;
    }

    # check for non-existing buckets first/next/last
    {
        my $bb = APR::Brigade->new($r->pool, $ba);

        ok t_cmp($bb->first, undef, "no first bucket");
        ok t_cmp($bb->last,  undef, "no last bucket");

        ## now there is first
        my $b = APR::Bucket->new($ba, "bbb");
        $bb->insert_head($b);
        my $b_first = $bb->first;
        $b->read(my $read);
        ok t_cmp($read, "bbb", "first bucket");

        # but there is no prev
        ok t_cmp($bb->prev($b_first), undef, "no prev bucket");

        # and no next
        ok t_cmp($bb->next($b_first), undef, "no next bucket");
    }

    # delete+destroy
    {
        my $bb = APR::Brigade->new($r->pool, $ba);
        $bb->insert_head(APR::Bucket->new($ba, "a"));
        $bb->insert_head(APR::Bucket->new($ba, "b"));

        my $b1 = $bb->first;
        $b1->remove;
        $b1->destroy;
        ok 1;

        # delete = remove + destroy
        my $b2 = $bb->first;
        $b2->delete;
        ok 1;
    }

    return Apache2::Const::OK;
}

1;
