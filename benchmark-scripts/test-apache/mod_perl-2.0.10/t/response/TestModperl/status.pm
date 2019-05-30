# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::status;

use strict;
use warnings;

use Apache2::RequestRec;
use Apache2::Const -compile => qw(DECLINED);

use ModPerl::Util;
use Apache::TestUtil qw(t_server_log_error_is_expected);

sub handler {

    my $rc = shift->args;

    if ($rc eq 'die' ||
        $rc eq Apache2::Const::DECLINED ||
        $rc =~ m/foo/) {
        t_server_log_error_is_expected();
    }

    ModPerl::Util::exit if $rc eq 'exit';

    die if $rc eq 'die';

    return if $rc eq 'undef';

    return $rc;
}

1;
__END__
