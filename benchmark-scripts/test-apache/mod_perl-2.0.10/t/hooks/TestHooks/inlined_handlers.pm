# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::inlined_handlers;

# this test exercises httpd.conf inlined one-liner handlers, like:
#   PerlFixupHandler 'sub { use Apache2::Const qw(DECLINED); DECLINED }'
# previously there was a bug in non-ithreaded-perl implementation
# where the cached compiled CODE ref didn't have the reference count
# right.

use strict;
use warnings FATAL => 'all';

use Apache2::RequestIO ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->print('ok');

    Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks__inlined_handlers>
      SetHandler modperl
      PerlFixupHandler    'sub { use Apache2::Const qw(DECLINED); DECLINED }'
      PerlResponseHandler TestHooks::inlined_handlers
  </Location>
</NoAutoConfig>
