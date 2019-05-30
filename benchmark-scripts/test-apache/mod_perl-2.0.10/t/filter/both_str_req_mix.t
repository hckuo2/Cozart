# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1, need 'deflate', 'include',
    need_min_module_version("Compress::Zlib", "1.09");

require Compress::Zlib;
my $location = '/TestFilter__both_str_req_mix';

my $request_orig = '<!--#include INPUTvirtual="/includes/OUTPUTclear.shtml" -->';
my $response_orig = 'This is a clear text';

# gzip already produces data in a network order, so no extra
# transformation seem to be necessary

my $content = Compress::Zlib::memGzip($request_orig);
my $response_raw = POST_BODY $location,
    content            => $content,
    'Accept-Encoding'  => "gzip",
    'Content-Encoding' => "gzip";

#t_debug($response_raw);
my $response_clear = Compress::Zlib::memGunzip($response_raw);
#t_debug($response_clear);

my $expected = $response_orig;
(my $received = $response_clear) =~ s{\r?\n$}{};

ok t_cmp($received, $expected,
    "mixing httpd and mod_perl filters, while preserving order");

