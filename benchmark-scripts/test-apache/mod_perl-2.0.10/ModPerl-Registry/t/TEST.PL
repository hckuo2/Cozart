use strict;
use warnings FATAL => 'all';

use FindBin;
# test against the source lib for easier dev
use lib "$FindBin::Bin/../lib";
use lib grep { -d } map "$FindBin::Bin/../../$_", qw(lib Apache-Test/lib);

# pick the common test libs
use lib "$FindBin::Bin/../../t/lib";

MyTest->new->run(@ARGV);



# sub-class Apache::TestRunPerl
package MyTest;

use base qw(Apache::TestRunPerl);

# redirect tests require 2 servers
use constant MIN_CLIENTS => 2;

use File::Spec::Functions qw(catdir);
use File::Basename qw(dirname);

use Apache2::Build;

# default timeout in secs (threaded mpms are extremely slow to
# startup, due to a slow perl_clone operation)
use constant DEFAULT_STARTUP_TIMEOUT =>
    Apache2::Build->build_config->mpm_is_threaded() ? 180 : 90;

# subclass new_test_config to add some config vars which will be
# replaced in generated httpd.conf
sub new_test_config {
    my $self = shift;

    require Apache::Test;
    my $mp2_root_dir = dirname Apache::Test::vars('top_dir');
    $self->{conf_opts}->{src_dir} = catdir $mp2_root_dir,
        qw(src modules perl);

    $self->{conf_opts}->{startup_timeout} ||=
        $ENV{APACHE_TEST_STARTUP_TIMEOUT} ||
        DEFAULT_STARTUP_TIMEOUT;

    $self->{conf_opts}->{minclients} ||= MIN_CLIENTS;

    return $self->SUPER::new_test_config;
}

sub bug_report {
    require ModPerl::TestRun;
    shift->ModPerl::TestRun::bug_report();
}
