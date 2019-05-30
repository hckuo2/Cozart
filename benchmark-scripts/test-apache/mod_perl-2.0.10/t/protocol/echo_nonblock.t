# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest ();

plan tests => 3;

my $socket = Apache::TestRequest::vhost_socket('TestProtocol::echo_nonblock');

ok $socket;

my $received;
my $expected;

$expected = "nonblocking";
print $socket "$expected\n";
chomp($received = <$socket> || '');
ok t_cmp $received, $expected, "no timeout";

# now get a timed out request
$expected = "TIMEUP";
sleep 1; # try to ensure a CPU context switch for the server
print $socket "should timeout\n";
chomp($received = <$socket> || '');
ok t_cmp $received, $expected, "timed out";

