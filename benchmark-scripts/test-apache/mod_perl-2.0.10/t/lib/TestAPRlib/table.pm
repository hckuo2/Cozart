# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPRlib::table;

# testing APR::Table API

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Table ();
use APR::Pool ();

use APR::Const -compile => ':table';

use constant TABLE_SIZE => 20;
our $filter_count;

sub num_of_tests {
    my $tests = 56;

    # tied hash values() for a table w/ multiple values for the same
    # key
    $tests += 2 if $] >= 5.008;

    return $tests;
}

sub test {

    $filter_count = 0;
    my $pool = APR::Pool->new();
    my $table = APR::Table::make($pool, TABLE_SIZE);

    ok UNIVERSAL::isa($table, 'APR::Table');

    # get on non-existing key
    {
        # in scalar context
        my $val = $table->get('foo');
        ok t_cmp($val, undef, '$val = $table->get("no_such_key")');

        # in list context
        my @val = $table->get('foo');
        ok t_cmp(+@val, 0, '@val = $table->get("no_such_key")');
    }

    # set/add/get/copy normal values
    {
        $table->set(foo => 'bar');

        # get scalar context
        my $val = $table->get('foo');
        ok t_cmp($val, 'bar', '$val = $table->get("foo")');

        # add + get list context
        $table->add(foo => 'tar');
        $table->add(foo => 'kar');
        my @val = $table->get('foo');
        ok @val == 3         &&
            $val[0] eq 'bar' &&
            $val[1] eq 'tar' &&
            $val[2] eq 'kar';

        # copy
        $table->set(too => 'boo');
        my $table_copy = $table->copy($pool);
        my $val_copy = $table->get('too');
        ok t_cmp($val_copy, 'boo', '$val = $table->get("too")');
        my @val_copy = $table_copy->get('foo');
        ok @val_copy == 3         &&
            $val_copy[0] eq 'bar' &&
            $val_copy[1] eq 'tar' &&
            $val_copy[2] eq 'kar';
    }

    # make sure 0 comes through as 0 and not undef
    {
        $table->set(foo => 0);
        my $zero = $table->get('foo');
        ok t_cmp($zero, 0, 'table value 0 is not undef');
    }

    # unset
    {
        $table->set(foo => "bar");
        $table->unset('foo');
        ok t_cmp(+$table->get('foo'), undef, '$table->unset("foo")');
    }

    # merge
    {
        $table->set(  merge => '1');
        $table->merge(merge => 'a');
        my $val = $table->get('merge');
        ok t_cmp($val, "1, a", 'one val $table->merge(...)');

        # if there is more than one value for the same key, merge does
        # the job only for the first value
        $table->add(  merge => '2');
        $table->merge(merge => 'b');
        my @val = $table->get('merge');
        ok t_cmp($val[0], "1, a, b", '$table->merge(...)');
        ok t_cmp($val[1], "2",       'two values $table->merge(...)');

        # if the key is not found, works like set/add
        $table->merge(miss => 'a');
        my $val_miss = $table->get('miss');
        ok t_cmp($val_miss, "a", 'no value $table->merge(...)');
    }

    # clear
    {
        $table->set(foo => 0);
        $table->set(bar => 1);
        $table->clear();
        # t_cmp forces scalar context on get
        ok t_cmp($table->get('foo'), undef, '$table->clear');
        ok t_cmp($table->get('bar'), undef, '$table->clear');
    }

    # filtering
    {
        for (1..TABLE_SIZE) {
            $table->set(chr($_+97), $_);
        }

        # Simple filtering
        $filter_count = 0;
        $table->do("my_filter");
        ok t_cmp($filter_count, TABLE_SIZE);

        # Filtering aborting in the middle
        $filter_count = 0;
        $table->do("my_filter_stop");
        ok t_cmp($filter_count, int(TABLE_SIZE)/2) ;

        # Filtering with anon sub
        $filter_count=0;
        $table->do(sub {
            my ($key,$value) = @_;
            $filter_count++;
            unless ($key eq chr($value+97)) {
                die "arguments I recieved are bogus($key,$value)";
            }
            return 1;
        });

        ok t_cmp($filter_count, TABLE_SIZE, "table size");

        $filter_count = 0;
        $table->do("my_filter", "c", "b", "e");
        ok t_cmp($filter_count, 3, "table size");
    }

    #Tied interface
    {
        my $table = APR::Table::make($pool, TABLE_SIZE);

        ok UNIVERSAL::isa($table, 'HASH');

        ok UNIVERSAL::isa($table, 'HASH') && tied(%$table);

        ok $table->{'foo'} = 'bar';

        # scalar context
        ok $table->{'foo'} eq 'bar';

        ok delete $table->{'foo'} || 1;

        ok not exists $table->{'foo'};

        for (1..TABLE_SIZE) {
            $table->{chr($_+97)} = $_;
        }

        $filter_count = 0;
        foreach my $key (sort keys %$table) {
            my_filter($key, $table->{$key});
        }
        ok $filter_count == TABLE_SIZE;
    }


    # each, values
    {
        my $table = APR::Table::make($pool, 2);

        $table->add("first"  => 1);
        $table->add("second" => 2);
        $table->add("first"  => 3);

        my $i = 0;
        while (my ($a,$b) = each %$table) {
            my $key = ("first", "second")[$i % 2];
            my $val = ++$i;

            ok t_cmp $a,           $key, "table each: key test";
            ok t_cmp $b,           $val, "table each: value test";
            ok t_cmp $table->{$a}, $val, "table each: get test";

            ok t_cmp tied(%$table)->FETCH($a), $val,
                "table each: tied get test";
        }

        # this doesn't work with Perl < 5.8
        if ($] >= 5.008) {
            ok t_cmp "1,2,3", join(",", values %$table),
                "table values";
            ok t_cmp "first,1,second,2,first,3", join(",", %$table),
                "table entries";
        }
    }

    # overlap and compress routines
    {
        my $base = APR::Table::make($pool, TABLE_SIZE);
        my $add  = APR::Table::make($pool, TABLE_SIZE);

        $base->set(foo => 'one');
        $base->add(foo => 'two');

        $add->set(foo => 'three');
        $add->set(bar => 'beer');

        my $overlay = $base->overlay($add, $pool);

        my @foo = $overlay->get('foo');
        my @bar = $overlay->get('bar');

        ok t_cmp(+@foo, 3);
        ok t_cmp($bar[0], 'beer');

        my $overlay2 = $overlay->copy($pool);

        # compress/merge
        $overlay->compress(APR::Const::OVERLAP_TABLES_MERGE);
        # $add first, then $base
        ok t_cmp($overlay->get('foo'),
                 'three, one, two',
                 "\$overlay->compress/merge");
        ok t_cmp($overlay->get('bar'),
                 'beer',
                 "\$overlay->compress/merge");

        # compress/set
        $overlay->compress(APR::Const::OVERLAP_TABLES_SET);
        # $add first, then $base
        ok t_cmp($overlay2->get('foo'),
                 'three',
                 "\$overlay->compress/set");
        ok t_cmp($overlay2->get('bar'),
                 'beer',
                 "\$overlay->compress/set");
    }

    # overlap set
    {
        my $base = APR::Table::make($pool, TABLE_SIZE);
        my $add  = APR::Table::make($pool, TABLE_SIZE);

        $base->set(bar => 'beer');
        $base->set(foo => 'one');
        $base->add(foo => 'two');

        $add->set(foo => 'three');

        $base->overlap($add, APR::Const::OVERLAP_TABLES_SET);

        my @foo = $base->get('foo');
        my @bar = $base->get('bar');

        ok t_cmp(+@foo, 1, 'overlap/set');
        ok t_cmp($foo[0], 'three');
        ok t_cmp($bar[0], 'beer');
    }

    # overlap merge
    {
        my $base = APR::Table::make($pool, TABLE_SIZE);
        my $add  = APR::Table::make($pool, TABLE_SIZE);

        $base->set(foo => 'one');
        $base->add(foo => 'two');

        $add->set(foo => 'three');
        $add->set(bar => 'beer');

        $base->overlap($add, APR::Const::OVERLAP_TABLES_MERGE);

        my @foo = $base->get('foo');
        my @bar = $base->get('bar');

        ok t_cmp(+@foo, 1, 'overlap/set');
        ok t_cmp($foo[0], 'one, two, three');
        ok t_cmp($bar[0], 'beer');
    }


    # temp pool objects.
    # testing here that the temp pool object doesn't go out of scope
    # before the object based on it was freed. the following tests
    # were previously segfaulting when using apr1/httpd2.1 built w/
    # --enable-pool-debug CPPFLAGS="-DAPR_BUCKET_DEBUG",
    # the affected methods are:
    # - make
    # - copy
    # - overlay
    {
        {
            my $table = APR::Table::make(APR::Pool->new, 10);
            $table->set($_ => $_) for 1..20;
            ok t_cmp $table->get(20), 20, "no segfault";
        }

        my $pool = APR::Pool->new;
        my $table = APR::Table::make($pool, 10);
        $table->set($_ => $_) for 1..20;
        my $table_copy = $table->copy($pool->new);
        {
            # verify that the temp pool used to create $table_copy was
            # not freed, by allocating a new table to fill with a
            # different data. if that former pool was freed
            # $table_copy will now contain bogus data (and may
            # segfault)
            my $table = APR::Table::make(APR::Pool->new, 50);
            $table->set($_ => $_) for 'a'..'z';
            ok t_cmp $table->get('z'), 'z', "helper test";

        }
        ok t_cmp $table_copy->get(20), 20, "no segfault/valid data";

        my $table2 = APR::Table::make($pool, 1);
        $table2->set($_**2 => $_**2) for 1..20;
        my $table2_copy = APR::Table::make($pool, 1);
        $table2_copy->set($_ => $_) for 1..20;

        my $overlay = $table2_copy->overlay($table2, $pool->new);
        {
            # see the comment for above's:
            # $table_copy = $table->copy(APR::Pool->new);
            my $table = APR::Table::make(APR::Pool->new, 50);
            $table->set($_ => $_) for 'aa'..'za';
            ok t_cmp $table->get('za'), 'za', "helper test";

        }
        ok t_cmp $overlay->get(20), 20, "no segfault/valid data";
    }
    {
        {
            my $p = APR::Pool->new;
            $p->cleanup_register(sub { "whatever" });
            $table = APR::Table::make($p, 10)
        };
        $table->set(a => 5);
        ok t_cmp $table->get("a"), 5, "no segfault";
    }

}

sub my_filter {
    my ($key, $value) = @_;
    $filter_count++;
    unless ($key eq chr($value+97)) {
        die "arguments I received are bogus($key,$value)";
    }
    return 1;
}

sub my_filter_stop {
    my ($key, $value) = @_;
    $filter_count++;
    unless ($key eq chr($value+97)) {
        die "arguments I received are bogus($key,$value)";
    }
    return $filter_count == int(TABLE_SIZE)/2 ? 0 : 1;
}

1;
