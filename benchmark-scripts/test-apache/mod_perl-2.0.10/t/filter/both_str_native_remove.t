# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 8, need 'deflate', 'include',
    need_min_module_version("Compress::Zlib", "1.09");

require Compress::Zlib;

my $base = '/TestFilter__both_str_native_remove';

# 1. check if DEFLATE input and INCLUDES output filter work
{
    my $location = $base;
    my $received = POST_BODY $location,
        content => Compress::Zlib::memGzip('gzipped text'),
        'Content-Encoding' => "gzip";

    ok t_cmp $received, qr/xSSI OK/, "INCLUDES filter";

    ok t_cmp $received, qr/content: gzipped text/, "DEFLATE filter";
}


# 2. check if DEFLATE input and INCLUDES output filter can be removed
{
    my $location = "$base?remove";
    my $received = POST_BODY $location, content => 'plain text';

    ok t_cmp $received,
        qr/input1: [\w,]+deflate/,
        "DEFLATE filter is present";

    ok !t_cmp $received,
        qr/input2: [\w,]+deflate/,
        "DEFLATE filter is removed";

    ok t_cmp $received,
        qr/content: plain text/,
        "DEFLATE filter wasn't invoked";

    ok t_cmp $received,
        qr/output1: modperl_request_output,includes,modperl_request_output,/,
        "INCLUDES filter is present";

    ok t_cmp $received,
        qr/output2: modperl_request_output,(?!includes)/,
        "INCLUDES filter is removed";

    ok t_cmp $received,
        qr/x<!--#echo var="SSI_TEST" -->x/,
        "INCLUDES filter wasn't invoked";

}


