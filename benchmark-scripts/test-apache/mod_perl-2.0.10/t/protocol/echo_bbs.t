# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest ();

my @test_strings = qw(hello wonderful world);

plan tests => 1 + @test_strings;

my $socket = Apache::TestRequest::vhost_socket('TestProtocol::echo_bbs');

ok $socket;

for (@test_strings) {
    print $socket "$_\n";
    chomp(my $reply = <$socket>||'');
    ok t_cmp($reply, uc($_));
}
