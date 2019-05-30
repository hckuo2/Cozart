# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

use File::Spec::Functions qw(catfile);

plan tests => 1;

#force test to go over http, since this doesn't work with t/TEST -ssl
Apache::TestRequest::scheme('http');

my $location = "/TestApache__read";

my $socket = Apache::TestRequest::vhost_socket('default');

my $file = catfile Apache::Test::vars('serverroot'), "..", 'Makefile';

open my $fh, $file or die "open $file: $!";
my $data = join '', <$fh>;
close $fh;

my $size = length $data;

for my $string ("POST $location http/1.0",
                "Content-length: $size",
                "") {
    my $line = "$string\r\n";
    syswrite $socket, $line, length($line);
}

my $written = 0;
my $bufsiz = 240;

my $sleeps = 2;

while ($written < length($data)) {
    my $remain = length($data) - $written;
    my $len = $remain > $bufsiz ? $bufsiz : $remain;
    $written += syswrite $socket, $data, $len, $written;
    sleep 1 if $sleeps-- > 0;
}

while (<$socket>) {
    last if /^\015?\012$/; #skip over headers
}

my $return = join '', <$socket>;

ok $data eq $return;
