# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest ();

my @test_strings = qw(MODPERL 2.0 RULES);

# blocking socket bug fixed in 2.0.52
my $ok = $^O !~ /^(Open|Net)BSD$/i || need_min_apache_version('2.0.52');

plan tests => 1 + @test_strings, $ok;

my $module = "TestFilter::both_str_con_add";
my $socket = Apache::TestRequest::vhost_socket($module);

ok $socket;

for my $str (@test_strings) {
    print $socket "$str\n";
    chomp(my $reply = <$socket>||'');
    $str = lc $str;
    $str =~ s/modperl/mod_perl/;
    ok t_cmp($reply, $str);
}
