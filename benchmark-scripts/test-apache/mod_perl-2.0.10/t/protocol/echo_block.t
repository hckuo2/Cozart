# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest ();

my @test_strings = qw(hello world);

# blocking socket bug fixed in 2.0.52
my $ok = $^O !~ /^(Open|Net)BSD$/i || need_min_apache_version('2.0.52');

plan tests => 1 + @test_strings, $ok;

my $socket = Apache::TestRequest::vhost_socket('TestProtocol::echo_block');

ok $socket;

for (@test_strings) {
    print $socket "$_\n";
    chomp(my $reply = <$socket>||'');
    ok t_cmp($reply, $_);
}
