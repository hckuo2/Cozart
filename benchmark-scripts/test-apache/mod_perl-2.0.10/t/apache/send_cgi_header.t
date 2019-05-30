# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 4;

my $location = "/TestApache__send_cgi_header";
my $res = GET $location;

ok t_cmp($res->header('X-Foo'),
         'X-Bar',
         "header test");

ok t_cmp($res->header('Set-Cookie'),
         'Bad Programmer, No cookie!',
         "header test2");

my $expected = "\0\0This not the end of the world\0\0\n";
my $received = $res->content;

ok t_cmp(length($received),
         length($expected),
         "body length test");

# \000 aren't seen when printed
ok t_cmp($received,
         $expected,
         "body content test");
