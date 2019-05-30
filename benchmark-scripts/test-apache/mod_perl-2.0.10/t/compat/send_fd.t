# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

use File::Spec::Functions qw(catfile);

plan tests => 3, need 'HTML::HeadParser';

my $config = Apache::Test::config();

my $url = '/TestCompat__send_fd';

my $data = GET_BODY($url);

ok $data;

my $module = catfile Apache::Test::vars('serverroot'),
    'response/TestCompat/send_fd.pm';

ok length($data) == -s $module;

$data = GET_BODY("$url?noexist.txt");

ok $data =~ /Not Found/;
