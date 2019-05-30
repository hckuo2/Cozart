# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

use Config;

# utf encode/decode was added only in 5.8.0
# perlio is needed only for the client side, because it calls binmode(STDOUT, ':utf8');
plan tests => 1, need_min_perl_version(5.008);

my $location = "/TestModperl__print_utf8_2";
my $expected = "\$r->print() just works \x{263A}";

my $res = GET $location;
my $received = $res->content;

# response body includes wide-chars, but perl doesn't know about it
utf8::decode($received) if ($res->header('Content-Type')||'') =~ /utf-8/i;

if ($Config{useperlio}) {
    # needed for debugging print out of utf8 strings
    # but works only if perl is built w/ perlio
    binmode(STDOUT, ':utf8');
    ok t_cmp($received, $expected, 'UTF8 response via $r->print');
}
else {
    ok $expected eq $received;
}

