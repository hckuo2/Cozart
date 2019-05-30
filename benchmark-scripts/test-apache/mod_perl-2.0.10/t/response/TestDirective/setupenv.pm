# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::setupenv;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $ENV{QS} = $r->args if $r->args;

    while (my ($key, $val) = each %ENV) {
        next unless $key and $val;
        $r->puts("$key=$val\n");
    }

    Apache2::Const::OK;
}

1;
__END__
PerlOptions +SetupEnv

