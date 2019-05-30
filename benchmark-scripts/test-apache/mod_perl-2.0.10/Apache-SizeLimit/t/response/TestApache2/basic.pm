package TestApache2::basic;

use strict;
use warnings;

use Apache::Test qw(-withtestmore);

use Apache2::Const -compile => qw(OK);
use Apache2::SizeLimit;
use Config;

use constant ONE_MB => 1024;
use constant TEN_MB => 1024 * 10;

sub handler {
    my $r = shift;

    plan $r, tests => 10;

    {
        local ($Apache::SizeLimit::Core::MAX_PROCESS_SIZE,
               $Apache::SizeLimit::Core::MIN_SHARE_SIZE,
               $Apache::SizeLimit::Core::MAX_UNSHARED_SIZE);
        ok( ! Apache2::SizeLimit->_limits_are_exceeded(),
            'check that _limits_are_exceeded() returns false without any limits set' );
    }

    {
        my ( $size, $shared ) = Apache2::SizeLimit->_check_size();
        cmp_ok( $size, '>', 0, 'proc size is reported > 0' );

        {
            # test with USE_SMAPS=0
            my $smaps = $Apache2::SizeLimit::USE_SMAPS;
            $Apache2::SizeLimit::USE_SMAPS = 0;
            my ( $size, $shared ) = Apache2::SizeLimit->_check_size();
            cmp_ok( $size, '>', 0, 'proc size is reported > 0' );
            $Apache2::SizeLimit::USE_SMAPS = $smaps;
        }

    SKIP:
        {
            skip 'I have no idea what getppid() on Win32 might return', 1
                if $Config{'osname'} eq 'MSWin32';

            cmp_ok( Apache2::SizeLimit->_platform_getppid(), '>', 1,
                    'real_getppid() > 1' );
        }
    }

    {
        # We can assume this will use _at least_ 10MB of memory, based on
        # assuming a scalar consumes >= 1K.
        my @big = ('x') x TEN_MB;

        my ( $size, $shared ) = Apache2::SizeLimit->_check_size();
        cmp_ok( $size, '>', TEN_MB, 'proc size is reported > ' . TEN_MB );

        Apache2::SizeLimit->set_max_process_size(ONE_MB);

        ok( Apache2::SizeLimit->_limits_are_exceeded(),
            'check that _limits_are_exceeded() returns true based on max process size' );

    SKIP:
        {
            skip 'We cannot get shared memory on this platform.', 3
                unless $shared > 0;

            cmp_ok( $size, '>', $shared, 'proc size is greater than shared size' );

            Apache2::SizeLimit->set_max_process_size(0);
            Apache2::SizeLimit->set_min_shared_size( ONE_MB * 100 );

            ok( Apache2::SizeLimit->_limits_are_exceeded(),
                'check that _limits_are_exceeded() returns true based on min share size' );

            Apache2::SizeLimit->set_min_shared_size(0);
            Apache2::SizeLimit->set_max_unshared_size(1);

            ok( Apache2::SizeLimit->_limits_are_exceeded(),
                'check that _limits_are_exceeded() returns true based on max unshared size' );
        }
    }

    {
        # Lame test - A way to check that setting this _does_
        # something would be welcome ;)
        Apache2::SizeLimit->set_check_interval(10);
        is( $Apache2::SizeLimit::CHECK_EVERY_N_REQUESTS, 10,
            'set_check_interval set global' );
    }

    return Apache2::Const::OK;
}


1;
