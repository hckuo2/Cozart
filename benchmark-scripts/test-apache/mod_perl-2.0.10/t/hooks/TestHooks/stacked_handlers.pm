# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::stacked_handlers;

# this test exercises the execution of the stacked handlers and test
# whether the execution breaks when something different than OK or
# DECLINED is returned

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();

use Apache2::Const -compile => qw(OK DECLINED DONE);

sub handler {
    my $r = shift;

    $r->handler("modperl");
    $r->push_handlers(PerlResponseHandler => [\&one, \&two, \&three, \&four]);

    return Apache2::Const::OK;
}

sub one {
    my $r = shift;

    $r->content_type('text/plain');
    $r->print("one\n");

    return Apache2::Const::DECLINED;
}

sub two {
    my $r = shift;

    $r->print("two\n");

    return Apache2::Const::DECLINED;
}

sub three {
    my $r = shift;

    $r->print("three\n");

    return Apache2::Const::DONE;
}

# this one shouldn't get called, because the handler 'three' has
# returned DONE
sub four {
    my $r = shift;

    $r->print("four\n");

    return Apache2::Const::OK;
}


1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks__stacked_handlers>
      SetHandler modperl
      PerlHeaderParserHandler TestHooks::stacked_handlers
  </Location>
</NoAutoConfig>

