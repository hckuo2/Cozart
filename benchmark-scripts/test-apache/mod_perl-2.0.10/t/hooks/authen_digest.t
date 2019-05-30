# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 7, need need_lwp, 'auth_digest', 'HTML::HeadParser';

my $location = '/TestHooks__authen_digest';

{
    my $response = GET $location;

    ok t_cmp($response->code,
             200,
             'handler returned HTTP_OK');

    my $wwwauth = $response->header('WWW-Authenticate');

    t_debug('response had no WWW-Authenticate header');
    ok (!$wwwauth);
}

{
    my $response = GET "$location?fail";

    ok t_cmp($response->code,
             401,
             'handler returned HTTP_UNAUTHORIZED');

    my $wwwauth = $response->header('WWW-Authenticate');

    t_debug('response had a WWW-Authenticate header');
    ok ($wwwauth);

    ok t_cmp($wwwauth,
             qr/^Digest/,
             'response is using Digest authentication scheme');

    ok t_cmp($wwwauth,
             qr/realm="Simple Digest"/,
             'WWW-Authenticate header contains the proper realm');

    ok t_cmp($wwwauth,
             qr/nonce="/,
             'WWW-Authenticate header contains a nonce');

    # other fields, such as qop, are added only if add additional
    # configuration directives, such as AuthDigestQop
}
