# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use File::Spec::Functions qw(catdir catfile);

my $url = '/TestFilter__out_bbs_filebucket';

my $dir = catdir Apache::Test::vars('documentroot'), qw(filter);

my @sizes = qw(1 100 500 1000 5000);

plan tests => 2 * scalar @sizes;

for my $size (@sizes) {
    my ($file, $data) = write_file($size);
    my $received = GET_BODY "$url?$file";

    my $received_size = length $received;
    my $expected_size = $size * 1024;

    ok t_cmp length($received), length($data), "length";
    ok $received && $received eq uc($data);
    unlink $file;
}

sub write_file {
    my $size = shift;

    my $data = "abcd" x ($size * 256);

    my $file = catfile $dir, "data_${size}k.txt";
    open my $fh, ">$file" or die "can't open $file: $!";
    # need binmode on Win32 so as not to strip \r, which
    # are included when sending with sendfile().
    binmode $fh;
    print $fh $data;
    close $fh;

    return ($file, $data);
}


