# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_autoload;

# test that PerlInputFilterHandler autoloads the module containing the
# handler (since it's ::handler and not a custom sub name we don't
# have to explicitly call PerlModule)
#
# no point testing PerlOutputFilterHandler as it does the same

use strict;
use warnings FATAL => 'all';

use Apache2::Filter ();

use Apache::TestTrace;

use Apache2::Const -compile => qw(OK);

sub handler {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        debug "filter read: $buffer";
        $filter->print(lc $buffer);
    }

    return Apache2::Const::OK;
}

1;

__DATA__
<NoAutoConfig>
  PerlModule TestCommon::Handlers
  <Location /TestFilter__in_autoload>
      SetHandler modperl
      PerlResponseHandler    TestCommon::Handlers::pass_through_response_handler
      # no PerlModule TestFilter::in_load on purpose
      PerlInputFilterHandler TestFilter::in_autoload
  </Location>
</NoAutoConfig>
