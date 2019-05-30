# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 2;

my $sep = "-0-";
my $data = join $sep, "aa" .. "zz";

(my $expected = $data) =~ s/$sep//g;
my $expected_len = length $expected;

my $location = '/TestFilter__out_str_buffer';
my $res = POST $location, content => $data;
#t_debug $res->as_string;
my $received_len = $res->header('Content-Length') || 0;
ok t_cmp $received_len, $expected_len, "Content-Length header";
ok t_cmp $res->content, $expected, "filtered data";

