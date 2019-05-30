# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::methodobj;

use strict;
use warnings FATAL => 'all';

use Apache2::Const -compile => 'OK';

use TestModperl::method ();

our @ISA = qw(TestModperl::method);

1;
__END__
PerlResponseHandler $TestModperl::MethodObj->handler

