# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestPreConnection::note;

use strict;
use warnings FATAL => 'all';

use Apache2::Connection ();

use Apache::TestTrace;
use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);
use constant APACHE24   => have_min_apache_version('2.4.0');

sub handler {
    my Apache2::Connection $c = shift;

    my $ip = APACHE24 ? $c->client_ip : $c->remote_ip;

    debug "ip: $ip";

    $c->notes->set(preconnection => $ip);

    return Apache2::Const::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');
    $r->print($r->connection->notes->get('preconnection') || '');

    return Apache2::Const::OK
}

1;
__END__
<NoAutoConfig>
  <VirtualHost TestPreConnection::note>
    PerlPreConnectionHandler TestPreConnection::note

    <Location /TestPreConnection__note>
      SetHandler modperl
      PerlResponseHandler TestPreConnection::note::response
    </Location>
  </VirtualHost>
</NoAutoConfig>


