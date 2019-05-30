# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModules::cgipost2;

# this handler doesn't use the :Apache layer, so CGI.pm needs to do
# $r->read(...)  instead of read(STDIN,...)

use strict;
use warnings FATAL => 'all';

use Apache2::compat ();
use CGI ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    my $cgi = CGI->new($r);

    $r->print(join ":", map { $cgi->param($_) } $cgi->param);

    Apache2::Const::OK;
}

1;
__END__

