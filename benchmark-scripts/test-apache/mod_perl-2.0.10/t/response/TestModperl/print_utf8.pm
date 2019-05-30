# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::print_utf8;

# testing the utf8-encoded response via a tied STDOUT/perlio STDOUT,
# the latter if perl was built with perlio.
# see Modperl/print_utf8_2.pm for $r->print

# must test against a tied STDOUT/perlio STDOUT. $r->print does the
# right thing without any extra provisions

use strict;
use warnings FATAL => 'all';

use Apache2::RequestIO ();
use Apache2::RequestRec ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->content_type('text/plain; charset=UTF-8');

    # prevent warning: "Wide character in print"
    binmode(STDOUT, ':utf8'); # Apache2::RequestRec::BINMODE()

    # must be non-$r->print(), so we go through the tied STDOUT
    # \x{263A} == :-)
    print "Hello Ayhan \x{263A} perlio rules!";

    Apache2::Const::OK;
}

1;
__DATA__
SetHandler perl-script
