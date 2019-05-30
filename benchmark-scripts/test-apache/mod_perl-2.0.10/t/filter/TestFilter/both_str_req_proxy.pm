# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::both_str_req_proxy;

# very similar to TestFilter::both_str_req_add, but the request is
# proxified. we filter the POSTed body before it goes via the proxy and
# we filter the response after it returned from the proxy

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();

use Apache::TestTrace;

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);

sub in_filter {
    my $filter = shift;

    debug "input filter";

    while ($filter->read(my $buffer, 1024)) {
        $filter->print(lc $buffer);
    }

    Apache2::Const::OK;
}

sub out_filter {
    my $filter = shift;

    debug "output filter";

    while ($filter->read(my $buffer, 1024)) {
        $buffer =~ s/\s+//g;
        $filter->print($buffer);
    }

    Apache2::Const::OK;
}

sub handler {
    my $r = shift;

    debug "response handler";

    $r->content_type('text/plain');

    if ($r->method_number == Apache2::Const::M_POST) {
        $r->print(TestCommon::Utils::read_post($r));
    }

    return Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
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

        ProxyRequests Off

        ProxyPass    /TestFilter__both_str_req_proxy/ \
        http://@servername@:@port@/TestFilter__both_str_req_proxy_content/
        ProxyPassReverse /TestFilter__both_str_req_proxy/ \
        http://@servername@:@port@/TestFilter__both_str_req_proxy_content/
    </IfModule>

    PerlModule TestFilter::both_str_req_proxy
    <Location /TestFilter__both_str_req_proxy>
        PerlInputFilterHandler  TestFilter::both_str_req_proxy::in_filter
        PerlOutputFilterHandler TestFilter::both_str_req_proxy::out_filter
    </Location>
    <Location /TestFilter__both_str_req_proxy_content>
        SetHandler modperl
        PerlResponseHandler     TestFilter::both_str_req_proxy
    </Location>
</NoAutoConfig>




