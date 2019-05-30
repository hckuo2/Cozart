# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::error;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => 'OK';

use APR::Table ();

sub handler {
    my $r = shift;
    my $args = $r->args();
    if (defined($args) && $args ne '') {
        $r->notes->set('error-notes' => $args);
    }
    &bomb();
    Apache2::Const::OK;
}

sub fail {
    my $r = shift;
    $r->print('Error: '.$r->prev->notes->get('error-notes'));
    Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks__error>
      SetHandler modperl
      PerlResponseHandler TestHooks::error
      ErrorDocument 500 /TestHooks__error__fail
  </Location>
  <Location /TestHooks__error__fail>
      SetHandler modperl
      PerlResponseHandler TestHooks::error::fail
  </Location>
</NoAutoConfig>
