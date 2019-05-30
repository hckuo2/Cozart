use strict;
use warnings FATAL => 'all';

use Config;
use Apache::Test;

# skip all tests in this directory unless mod_perl is enabled for 2.x series
plan tests => 1, \&my_need;

ok 1;

sub my_need {

    my $ok = 1;

    if ( $Config{'osname'} eq 'linux' ) {
        $ok = need_module('Linux::Pid');
        if ( -e '/proc/self/smaps' ) {
            $ok &= need_module('Linux::Smaps');
        }
    }
    elsif ( $Config{'osname'} =~ /(bsd|aix)/i ) {
        $ok &= need_module('BSD::Resource');
    }
    elsif ( $Config{'osname'} eq 'MSWin32' ) {
        $ok &= need_module('Win32::API');
    }
    elsif ( $Config{'osname'} eq 'darwin' ) {
        push @Apache::Test::SkipReasons,
            "$Config{osname} is not supported - broken getrusage(3)";
        return 0;
    }

    $ok &= need_min_apache_version("2.0.48");

    eval { require mod_perl2; };
    $ok &= $mod_perl2::VERSION && $mod_perl2::VERSION >= 1.99022 ? 1 : 0; ## 2.0.0-RC5+

    $ok &= need_min_module_version('Test::Builder' => '0.18_01');

    return $ok;
}
