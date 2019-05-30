# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModules::cgiupload;

use strict;
use warnings FATAL => 'all';

use Apache2::compat ();
use CGI ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $cgi = CGI->new;

    my $file = $cgi->param('filename');

    while (<$file>) {
        print;
    }

    Apache2::Const::OK;
}

1;
__END__
SetHandler perl-script
PerlOptions +GlobalRequest
