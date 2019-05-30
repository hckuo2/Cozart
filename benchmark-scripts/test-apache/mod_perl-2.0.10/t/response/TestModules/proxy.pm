# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModules::proxy;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache2::ServerRec ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();

my $uri_real = "/TestModules__proxy_real";

use Apache2::Const -compile => qw(DECLINED OK PROXYREQ_REVERSE);

sub proxy {
    my $r = shift;

    return Apache2::Const::DECLINED if $r->proxyreq;
    return Apache2::Const::DECLINED unless $r->uri eq '/TestModules__proxy';

    my $s = $r->server;
    my $real_url = sprintf "http://%s:%d%s",
        $s->server_hostname, $s->port, $uri_real;

    $r->proxyreq(Apache2::Const::PROXYREQ_REVERSE);
    $r->uri($real_url);
    $r->filename("proxy:$real_url");
    $r->handler('proxy-server');

    return Apache2::Const::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');
    $r->print("ok");

    return Apache2::Const::OK;
}

1;
__END__
<NoAutoConfig>
  <VirtualHost TestModules::proxy>
    <IfModule mod_proxy.c>
        <Proxy http://@servername@:@port@/*>
            <IfModule mod_version.c>
                <IfVersion < 2.3.0>
                    <IfModule @ACCESS_MODULE@>
                        Order Deny,Allow
                        Deny from all
                        Allow from @servername@
                    </IfModule>
                </IfVersion>
                <IfVersion > 2.4.1>
                    <IfModule mod_access_compat.c>
                        Order Deny,Allow
                        Deny from all
                        Allow from @servername@
                    </IfModule>
                </IfVersion>
            </IfModule>
        </Proxy>

        PerlModule TestModules::proxy
        PerlTransHandler TestModules::proxy::proxy
        <Location /TestModules__proxy_real>
            SetHandler modperl
            PerlResponseHandler TestModules::proxy::response
        </Location>
    </IfModule>
  </VirtualHost>
</NoAutoConfig>

