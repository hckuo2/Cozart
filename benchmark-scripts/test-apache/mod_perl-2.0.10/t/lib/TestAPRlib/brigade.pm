# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPRlib::brigade;

# testing APR::Brigade in this tests.
# Other tests do that too:
# TestAPR::flatten : flatten()
# TestAPR::bucket  : is_empty(), first(), last()

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Pool ();
use APR::Brigade ();
use APR::Bucket ();
use APR::BucketAlloc ();

use Apache2::Const -compile => 'OK';

sub num_of_tests {
    return 14;
}

sub test {

    my $p = APR::Pool->new();
    my $ba   = APR::BucketAlloc->new($p);

    # basic + pool + destroy
    {
        my $bb = APR::Brigade->new($p, $ba);

        t_debug('$bb is defined');
        ok defined $bb;

        t_debug('$bb ISA APR::Brigade object');
        ok $bb->isa('APR::Brigade');

        my $pool = $bb->pool;

        t_debug('$pool is defined');
        ok defined $pool;

        t_debug('$pool ISA APR::Pool object');
        ok $pool->isa('APR::Pool');

        t_debug("destroy");
        $bb->destroy;
        ok 1;
    }

    # concat / split / length / flatten
    {
        my $bb1 = APR::Brigade->new($p, $ba);
        $bb1->insert_head(APR::Bucket->new($ba, "11"));
        $bb1->insert_tail(APR::Bucket->new($ba, "12"));

        my $bb2 = APR::Brigade->new($p, $ba);
        $bb2->insert_head(APR::Bucket->new($ba, "21"));
        $bb2->insert_tail(APR::Bucket->new($ba, "22"));

        # concat
        $bb1->concat($bb2);
        # bb1: 11, 12, 21, 22
        ok t_cmp($bb1->length, 8, "total data length in bb");
        my $len = $bb1->flatten(my $data);
        ok t_cmp($len, 8, "bb flatten/len");
        ok t_cmp($data, "11122122", "bb flatten/data");
        t_debug('$bb2 is empty');
        ok $bb2->is_empty;

        # split
        my $b = $bb1->first; # 11
        $b = $bb1->next($b); # 12
        my $bb3 = $bb1->split($b);

        # bb1: 11, bb3: 12, 21, 22
        $len = $bb1->flatten($data);
        ok t_cmp($len, 2, "bb1 flatten/len");
        ok t_cmp($data, "11", "bb1 flatten/data");
        $len = $bb3->flatten($data);
        ok t_cmp($len, 6, "bb3 flatten/len");
        ok t_cmp($data, "122122", "bb3 flatten/data");
    }

    # out-of-scope pools
    {
        my $bb1 = APR::Brigade->new(APR::Pool->new, $ba);
        $bb1->insert_head(APR::Bucket->new($ba, "11"));
        $bb1->insert_tail(APR::Bucket->new($ba, "12"));

        # try to overwrite the temp pool data
        require APR::Table;
        my $table = APR::Table::make(APR::Pool->new, 50);
        $table->set($_ => $_) for 'aa'..'za';
        # now test that we are still OK

        my $len = $bb1->flatten(my $data);
        ok t_cmp($data, "1112", "correct data");
    }

    Apache2::Const::OK;
}

1;
