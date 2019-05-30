# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1;

my $blocks  = 33;
my $invoked = 67; # 33 bb made of data and 1 flush bucket (unbuffered print)
                  # 33 bb made of 1 flush bucket (rflush)
                  #  1 bb with EOS bucket
my $sig = join "\n", "received $blocks complete blocks",
    "filter invoked $invoked times\n";
my $data = "#" x $blocks . "x" x $blocks;
my $expected = join "\n", $data, $sig;

{
    # test the filtering of the mod_perl response handler
    my $location = '/TestFilter__out_str_ctx';
    my $response = GET_BODY $location;
    ok t_cmp($response, $expected, "context stream filter");
}
