# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1, need_min_module_version("Compress::Zlib", "1.09");

my $location = '/TestAPI__content_encoding';

my $expected = 'This is a clear text';

my $res = POST $location, content => $expected;

my $received = $res->content;
#t_debug($received);

if ($res->header('Content-Encoding') =~ /gzip/) {
    require Compress::Zlib;

    # gzip already produces data in a network order, so no extra
    # transformation seem to be necessary
    $received = Compress::Zlib::memGunzip($received);
}

ok t_cmp $received, $expected, "Content-Encoding: gzip test";

