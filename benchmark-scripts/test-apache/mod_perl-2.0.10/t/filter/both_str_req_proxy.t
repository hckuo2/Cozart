# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

my @modules = qw(mod_proxy proxy_http.c);
push @modules, 'mod_access_compat.c' if have_min_apache_version("2.4.0");
plan tests => 1, need need_module(@modules), need_access;

my $data = join ' ', 'A'..'Z', 0..9;
my $expected = lc $data; # that's what the input filter does
$expected =~ s/\s+//g;   # that's what the output filter does
my $location = '/TestFilter__both_str_req_proxy/foo';
my $response = POST_BODY $location, content => $data;
ok t_cmp($response, $expected, "lc input and reverse output filters");

