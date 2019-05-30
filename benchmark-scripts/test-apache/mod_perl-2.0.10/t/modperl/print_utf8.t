# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

# utf encode/decode was added only in 5.8.0
# XXX: currently binmode is only available with perlio (used on the
# server side on the tied/perlio STDOUT)
plan tests => 1, need need_min_perl_version(5.008), need_perl('perlio');

my $location = "/TestModperl__print_utf8";
my $expected = "Hello Ayhan \x{263A} perlio rules!";

my $res = GET $location;
my $received = $res->content;

# response body includes wide-chars, but perl doesn't know about it
utf8::decode($received) if ($res->header('Content-Type')||'') =~ /utf-8/i;

# needed for debugging print out of utf8 strings
binmode(STDOUT, ':utf8');
ok t_cmp($received, $expected, 'UTF8 response via tied/perlio STDOUT');

