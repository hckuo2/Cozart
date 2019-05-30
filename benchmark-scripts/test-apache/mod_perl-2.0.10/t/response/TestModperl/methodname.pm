# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::methodname;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => 'OK';

use TestModperl::method ();

#no : method attribute required when -> config syntax is used
sub response {
    TestModperl::method::handler(@_);
}

1;
__END__
PerlResponseHandler TestModperl::methodname->response
