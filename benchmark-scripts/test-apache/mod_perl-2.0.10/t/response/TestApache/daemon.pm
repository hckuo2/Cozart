# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::daemon;

# Apache2::ServerUtil tests

use strict;
use warnings FATAL => 'all';

use Apache2::ServerUtil ();

use Apache::TestConfig ();
use Apache::TestUtil;
use Apache::Test;

use constant WIN32 => Apache::TestConfig::WIN32;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 2;

    my $user_id = Apache2::ServerUtil->user_id;
    my $user_id_expected = WIN32 ? 0 : $<;

    ok t_cmp $user_id, $user_id_expected, "user id";

    my $group_id = Apache2::ServerUtil->group_id;
    my ($group_id_expected) = WIN32 ? 0 : ($( =~ /^(\d+)/);

    ok t_cmp $group_id, $group_id_expected, "group id";

    Apache2::Const::OK;
}

1;

__END__

