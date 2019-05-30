# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::scanhdrs2;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $location = $r->args;

    print "Location: $location\n\n";

    Apache2::Const::OK;
}

1;
__END__
SetHandler perl-script
PerlOptions +ParseHeaders
