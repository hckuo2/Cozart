# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPRlib::threadrwlock;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Const -compile => qw(EBUSY SUCCESS);
use APR::Pool();

sub num_of_tests {
    return 5;
}

sub test {

    require APR::ThreadRWLock;

    my $pool = APR::Pool->new();
    my $mutex = APR::ThreadRWLock->new($pool);

    ok $mutex;

    ok t_cmp($mutex->rdlock, APR::Const::SUCCESS,
             'rdlock == APR::Const::SUCCESS');

    ok t_cmp($mutex->unlock, APR::Const::SUCCESS,
             'unlock == APR::Const::SUCCESS');

    ok t_cmp($mutex->wrlock, APR::Const::SUCCESS,
             'wrlock == APR::Const::SUCCESS');

    ok t_cmp($mutex->unlock, APR::Const::SUCCESS,
             'unlock == APR::Const::SUCCESS');

}

1;
