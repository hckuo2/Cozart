# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use File::Spec;

my $uri = "/TestAPI__lookup_misc";

my $file = File::Spec->rel2abs(__FILE__);
open my $fh, $file or die "Can't open $file: $!";
my $data = do { binmode $fh; local $/; <$fh> };
close $fh;

plan tests => 2;

# lookup_file
{
    my $args = "subreq=lookup_file;file=$file";
    my $expected = $data;
    my $received = GET_BODY_ASSERT "$uri?$args";
    t_debug "lookup_file";
    ok $received eq $expected;
}

# lookup_method_uri
{
    my $args = "subreq=lookup_method_uri;uri=/lookup_method_uri";
    my $expected = "ok";
    my $received = GET_BODY_ASSERT "$uri?$args";
    ok t_cmp $received, $expected, "lookup_method_uri";
}
