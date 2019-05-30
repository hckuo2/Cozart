# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::push_handlers;

# test various ways to push handlers

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();

use Apache2::Const -compile => qw(OK DECLINED DONE);

sub handler {
    my $r = shift;

    $r->handler("modperl");

    $r->push_handlers(PerlResponseHandler => \&coderef);
    $r->push_handlers(PerlResponseHandler =>
        \&TestHooks::push_handlers::full_coderef);

    $r->push_handlers(PerlResponseHandler =>
        [\&coderef1, __PACKAGE__.'::coderef2', \&coderef3]);

    $r->push_handlers(PerlResponseHandler =>
        sub { return say(shift, "anonymous") });

    $r->push_handlers(PerlResponseHandler =>
        [sub { return say(shift, "anonymous1") },
         \&coderef4,
         sub { return say(shift, "anonymous3") },
        ]);

    $r->push_handlers(PerlResponseHandler => \&end);

    return Apache2::Const::DECLINED;
}

sub end { return Apache2::Const::DONE }
sub say { shift->print(shift,"\n"); return Apache2::Const::DECLINED }

sub conf {
    # this one is configured from httpd.conf
    my $r= shift;
    $r->content_type('text/plain');
    return say($r, "conf");
}

sub conf1        { return say(shift, "conf1")        }
sub conf2        { return say(shift, "conf2")        }
sub coderef      { return say(shift, "coderef")      }
sub coderef1     { return say(shift, "coderef1")     }
sub coderef2     { return say(shift, "coderef2")     }
sub coderef3     { return say(shift, "coderef3")     }
sub coderef4     { return say(shift, "coderef4")     }
sub full_coderef { return say(shift, "full_coderef") }

1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks__push_handlers>
      SetHandler modperl
      PerlHeaderParserHandler TestHooks::push_handlers
      PerlResponseHandler     TestHooks::push_handlers::conf
      PerlResponseHandler     TestHooks::push_handlers::conf1 TestHooks::push_handlers::conf2
  </Location>
</NoAutoConfig>

