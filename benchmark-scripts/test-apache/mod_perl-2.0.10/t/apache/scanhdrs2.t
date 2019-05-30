# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 5, need 'HTML::HeadParser';

my $module = 'TestApache__scanhdrs2';
my $location = "/$module";

my $redirect = 'http://perl.apache.org/';

my $res = GET "$location?$redirect", redirect_ok => 0;

ok t_cmp($res->header('Location')||'', $redirect,
         "Location header");

ok t_cmp($res->code, 302,
         "status == 302");

$redirect = '/index.html';

$res = GET "$location?$redirect", redirect_ok => 0;

ok t_cmp(!$res->header('Location'), 1,
         "no Location header");

ok t_cmp($res->code, 200,
         "status == 200");

ok t_cmp($res->content, qr{welcome to},
         "content is index.html");
