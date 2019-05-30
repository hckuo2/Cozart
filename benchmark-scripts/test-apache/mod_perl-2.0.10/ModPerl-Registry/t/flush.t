# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_BODY);

plan tests => 1, need [qw(mod_alias.c deflate HTML::HeadParser)],
    need_min_module_version("Compress::Zlib", "1.09"),
    need_min_apache_version("2.0.48");
# it requires httpd 2.0.48 because of the bug in mod_deflate:
# http://nagoya.apache.org/bugzilla/show_bug.cgi?id=22259

require Compress::Zlib;

my $url = "/registry_bb_deflate/flush.pl";

my $expected = "yet another boring test string";
my $received = GET_BODY $url, 'Accept-encoding' => 'gzip';
my $decompressed = Compress::Zlib::memGunzip($received);

ok t_cmp(
    $decompressed,
    $expected,
    "test flush body"
   );

