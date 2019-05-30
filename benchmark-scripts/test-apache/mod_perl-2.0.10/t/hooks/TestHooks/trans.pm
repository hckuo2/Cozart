# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::trans;

use strict;
use warnings FATAL => 'all';

use Apache::TestConfig ();

use Apache2::RequestRec ();

use Apache2::Const -compile => qw(OK DECLINED);

my %trans = (
    '/TestHooks/trans.pm' => sub {
        my $r = shift;
        $r->filename(__FILE__);
        Apache2::Const::OK;
    },
    '/phooey' => sub {
        my $r = shift;
        $r->filename(__FILE__); #filename is currently required
        $r->uri('/TestHooks::trans');
        Apache2::Const::OK;
    },
);

sub handler {
    my $r = shift;

    my $uri = $r->uri;

    my $handler = $trans{ $uri };

    return Apache2::Const::DECLINED unless $handler;

    $handler->($r);
}

1;
__DATA__
<NoAutoConfig>
  <VirtualHost TestHooks::trans>
    PerlTransHandler TestHooks::trans
    <Location /TestHooks__trans>
        PerlResponseHandler Apache::TestHandler::ok1
        SetHandler modperl
    </Location>
  </VirtualHost>
</NoAutoConfig>
