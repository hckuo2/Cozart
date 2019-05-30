# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::set_handlers;

# test various ways to reset/unset handlers list

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();

use Apache2::Const -compile => qw(OK);

sub handler {
    my $r = shift;

    # the first way to reset the handlers list is to pass undef
    # access handler phase will be not called for mp
    $r->set_handlers(PerlAccessHandler => undef);

    # the second way to reset the handlers list is to pass []
    # fixup must be not executed
    $r->set_handlers(PerlFixupHandler => \&fixup);
    $r->set_handlers(PerlFixupHandler => []);

    # normal override
    $r->set_handlers(PerlResponseHandler => sub { die "not to be called"});
    $r->set_handlers(PerlResponseHandler => [\&Apache::TestHandler::ok1]);
    $r->handler("modperl");

    return Apache2::Const::OK;
}

sub fixup {
    die "fixup must not be executed";
}

1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks__set_handlers>
      PerlHeaderParserHandler TestHooks::set_handlers
  </Location>
</NoAutoConfig>

