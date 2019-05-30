# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPRlib::bucket;

# a mix of APR::Bucket and APR::BucketType tests

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use TestCommon::Utils;

use APR::Pool ();
use APR::Bucket ();
use APR::BucketAlloc ();
use APR::BucketType ();
use APR::Table ();

use APR::Const -compile => 'SUCCESS';

sub num_of_tests {
    return 21;
}

sub test {

    my $pool = APR::Pool->new();
    my $ba   = APR::BucketAlloc->new($pool);

    # new: basic
    {
        my $data = "foobar";
        my $b = APR::Bucket->new($ba, $data);

        t_debug('$b is defined');
        ok defined $b;

        t_debug('$b ISA APR::Bucket object');
        ok $b->isa('APR::Bucket');

        my $type = $b->type;
        ok t_cmp $type->name, 'mod_perl SV bucket', "type";

        ok t_cmp $b->length, length($data), "modperl b->length";
    }

    # new: offset
    {
        my $data   = "foobartar";
        my $offset = 3;
        my $real = substr $data, $offset;
        my $b = APR::Bucket->new($ba, $data, $offset);
        my $rlen = $b->read(my $read);
        ok t_cmp $read, $real, 'new($data, $offset)/buffer';
        ok t_cmp $rlen, length($read), 'new($data, $offset)/len';
        ok t_cmp $b->start, $offset, 'offset';

    }

    # new: offset+len
    {
        my $data   = "foobartar";
        my $offset = 3;
        my $len    = 3;
        my $real = substr $data, $offset, $len;
        my $b = APR::Bucket->new($ba, $data, $offset, $len);
        my $rlen = $b->read(my $read);
        ok t_cmp $read, $real, 'new($data, $offset, $len)/buffer';
        ok t_cmp $rlen, length($read), 'new($data, $offse, $lent)/len';
    }

    # new: offset+ too big len
    {
        my $data   = "foobartar";
        my $offset = 3;
        my $len    = 10;
        my $real = substr $data, $offset, $len;
        my $b = eval { APR::Bucket->new($ba, $data, $offset, $len) };
        ok t_cmp $@,
            qr/the length argument can't be bigger than the total/,
            'new($data, $offset, $len_too_big)';
    }

    # modification of the source variable, affects the data
    # inside the bucket
    {
        my $data = "A" x 10;
        my $orig = $data;
        my $b = APR::Bucket->new($ba, $data);
        $data =~ s/^..../BBBB/;
        $b->read(my $read);
        ok t_cmp $read, $data,
            "data inside the bucket should get affected by " .
            "the changes to the Perl variable it's created from";
    }


    # APR::Bucket->new() with the argument PADTMP (which happens when
    # some function is re-entered) and the same SV is passed to
    # different buckets, which must be detected and copied away.
    {
        my @buckets  = ();
        my @data     = qw(ABCD EF);
        my @received = ();
        for my $str (@data) {
            my $b = func($ba, $str);
            push @buckets, $b;
        }

        # the creating of buckets and reading from them is done
        # separately on purpose
        for my $b (@buckets) {
            $b->read(my $out);
            push @received, $out;
        }

        # here we used to get: two pv: "ef\0d"\0, "ef"\0, as you can see
        # the first bucket had corrupted data.
        my @expected = map { lc } @data;
        ok t_cmp \@received, \@expected, "new(PADTMP SV)";

        # this function will pass the same SV to new(), causing two
        # buckets point to the same SV, and having the latest bucket's
        # data override the previous one
        sub func {
            my $ba = shift;
            my $data = shift;
            return APR::Bucket->new($ba, lc $data);
        }

    }

    # read data is tainted
    {
        my $data = "xxx";
        my $b = APR::Bucket->new($ba, $data);
        $b->read(my $read);
        ok t_cmp $read, $data, 'new($data)';
        ok TestCommon::Utils::is_tainted($read);
    }

    # remove/destroy
    {
        my $b = APR::Bucket->new($ba, "aaa");
        # remove $b when it's not attached to anything (not sure if
        # that should be an error)
        $b->remove;
        ok 1;

        # a dangling bucket needs to be destroyed
        $b->destroy;
        ok 1;

        # real remove from bb is tested in many other filter tests
    }

    # setaside
    {
        my $data = "A" x 10;
        my $expected = $data;
        my $b = APR::Bucket->new($ba, $data);
        my $status = $b->setaside($pool);
        ok t_cmp $status, APR::Const::SUCCESS, "setaside status";
        $data =~ s/^..../BBBB/;
        $b->read(my $read);
        ok t_cmp $read, $expected,
            "data inside the setaside bucket is unaffected by " .
            "changes to the Perl variable it's created from";
        $b->destroy;
    }

    # alloc_create on out-of-scope pools
    {
        # later may move that into a dedicated bucket_alloc test
        my $ba = APR::BucketAlloc->new(APR::Pool->new);
        # here if the pool is gone of scope destroy() will segfault
        $ba->destroy;
        ok 1;
    }

    # setaside on out-of-scope pools
    {
        # note that at the moment APR internally handles the situation
        # when the pool goes out of scope, so modperl doesn't need to do
        # any special handling of the pool object passed to setaside()
        # to insure that it survives as long as $b is alive
        #
        # to make sure that this doesn't change internally in APR, the
        # sub-test remains here
        my $data = "A" x 10;
        my $orig = $data;
        my $b = APR::Bucket->new($ba, $data);
        my $status = $b->setaside(APR::Pool->new);
        ok t_cmp $status, APR::Const::SUCCESS, "setaside status";

        # try to overwrite the temp pool data
        my $table = APR::Table::make(APR::Pool->new, 50);
        $table->set($_ => $_) for 'aa'..'za';

        # now test that we are still OK
        $b->read(my $read);
        ok t_cmp $read, $data,
            "data inside the setaside bucket is not corrupted";
        $b->destroy;
    }

    $ba->destroy;
}

1;

