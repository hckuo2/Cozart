# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

plan tests => 2, need [qw(mod_alias.c HTML::HeadParser)],
    need_min_module_version CGI => 3.08;

my $url = "/registry/cgi.pl";
my $res = GET $url;

ok t_cmp($res->header('Content-type'),
         qr{^text/html},
         "test 'Content-type header setting");

ok t_cmp(lc($res->content),
         '<b>done</b>',
         "test body");
