# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 2;

my $location = "/TestApache__post";
my $str;

my @data = (arizona => 'wildcats');
my %data = @data;

$str = POST_BODY $location, content => "@data";

ok $str;

my $data = join '&', map { "$_=$data{$_}" } keys %data;

$str = POST_BODY $location, content => $data;
ok t_cmp($str,
    join(':', length($data), $data),
    "POST");
