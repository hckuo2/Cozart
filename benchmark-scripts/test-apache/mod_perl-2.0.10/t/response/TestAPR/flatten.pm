# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::flatten;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use TestCommon::Utils;

use Apache2::RequestRec ();
use APR::Bucket ();
use APR::Brigade ();

use Apache2::Const -compile => 'OK';

sub handler {

    my $r = shift;

    plan $r, tests => 26;

    # first, create a brigade
    my $pool = $r->pool;
    my $ba   = $r->connection->bucket_alloc;

    my $bb   = APR::Brigade->new($pool, $ba);

    # now, let's put several buckets in it
    for (1 .. 10) {
        my $data = 'x' x 20000;
        my $bucket = APR::Bucket->new($ba, $data);
        $bb->insert_tail($bucket);
    }

    # ok, that's 10 buckets of 20,000 = 200,000 characters
    ok t_cmp($bb->length,
             200000,
             'APR::Brigade::length()');

    # syntax: require a $bb
    eval { APR::Brigade::flatten("") };

    ok t_cmp($@,
             qr!usage: \$bb->flatten\(\$buf, \[\$wanted\]\)!,
             'APR::Brigade::flatten() requires a brigade');

    # flatten() will slurp up the entire brigade
    # equivalent to calling apr_brigade_pflatten
    {
        my $len = $bb->flatten(my $data);

        verify($len, 200000, $data, 1);
    }

    # flatten(0) returns 0 bytes
    {
        my $len = $bb->flatten(my $data, 0);

        t_debug('$bb->flatten(0) returns a defined value');
        ok (defined $data);

        verify($len, 0, $data, 0);
    }


    # flatten($length) will return the first $length bytes
    # equivalent to calling apr_brigade_flatten
    {
        # small
        my $len = $bb->flatten(my $data, 30);
        verify($len, 30, $data, 1);
    }

    {
        # large
        my $len = $bb->flatten(my $data, 190000);
        verify($len, 190000, $data, 1);
    }

    {
        # more than enough
        my $len = $bb->flatten(my $data, 300000);
        verify($len, 200000, $data, 1);
    }

    # fetch from a brigade with no data in it
    {
        my $len = APR::Brigade->new($pool, $ba)->flatten(my $data);

        t_debug('empty brigade returns a defined value');
        ok (defined $data);

        verify($len, 0, $data, 0);
    }

    Apache2::Const::OK;
}

# this sub runs 3 sub-tests with a false $check_content
# and 4 otherwise
sub verify {
    my ($len, $expected_len, $data, $check_content) = @_;

    ok t_cmp($len,
             $expected_len,
             "\$bb->flatten(\$data, $len) returned $len bytes");
    ok t_cmp(length($data),
             $len,
             "\$bb->flatten(\$data, $len) returned all expected data");

    ok TestCommon::Utils::is_tainted($data);

    if ($check_content) {
        # don't use t_cmp() here, else we get 200,000 characters
        # to look at in verbose mode
        t_debug("data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }

}


1;
