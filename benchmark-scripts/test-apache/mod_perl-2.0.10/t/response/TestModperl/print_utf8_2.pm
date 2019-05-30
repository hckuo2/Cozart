# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::print_utf8_2;

# testing the utf8-encoded response via direct $r->print, which does the
# right thing without any extra provisions.
# see print_utf8.pm for tied STDOUT/perlio STDOUT, which requires extra work

use strict;
use warnings FATAL => 'all';

use Apache2::RequestIO ();
use Apache2::RequestRec ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->content_type('text/plain; charset=UTF-8');

    # \x{263A} == :-)
    $r->print("\$r->print() just works \x{263A}");

    Apache2::Const::OK;
}

1;
__DATA__
SetHandler modperl
