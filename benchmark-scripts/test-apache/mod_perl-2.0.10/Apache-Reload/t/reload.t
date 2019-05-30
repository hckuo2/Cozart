use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use File::Spec::Functions qw(catfile tmpdir);

Apache::TestRequest::user_agent(keep_alive => 1);

plan tests => 3, need 'HTML::HeadParser';

my $test_file = catfile qw(Reload Test.pm);

my $location = '/reload';

my @tests = qw(const prototype simple subpackage);

my $header = join '', <DATA>;

my $initial = <<'EOF';
sub simple { 'simple' }
use constant const => 'const';
sub prototype($) { 'prototype' }
sub promised;
EOF

my $modified = <<'EOF';
sub simple { 'SIMPLE' }
use constant const => 'CONST';
sub prototype($$) { 'PROTOTYPE' }
EOF

t_write_test_lib($test_file, $header, $initial);

{
    my $expected = join '', map { "$_:$_\n" } sort @tests;
    my $received = GET $location;
    ok t_cmp($received->content, $expected, 'Initial');
}

t_write_test_lib($test_file, $header, $modified);

{
    my $expected = join '', map { "$_:" . uc($_) . "\n" } sort @tests;
    my $received = GET $location;
    ok t_cmp($received->content, $expected, 'Reload');
}

{
    my $expected = "unregistered OK";
    my $received = GET "$location?last";
    ok t_cmp($received->content, $expected, 'Unregister');
}

__DATA__
package Reload::Test;

our @methods = qw(const prototype simple subpackage);

sub subpackage { return Reload::Test::SubPackage::subpackage() }

sub run {
    my $r = shift;
    foreach my $m (sort @methods) {
        $r->print($m, ':', __PACKAGE__->$m(), "\n");
    }
}

1;
