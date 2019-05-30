# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 2;

my @data = (join('', 'a'..'z'), join('', 0..9));

my $reversed_data = join '', map { scalar(reverse $_) . "\n" } @data;
my $normal_data   = join '', map { $_                 . "\n" } @data;
#t_debug($reversed_data);
my $sig = "Reversed by mod_perl 2.0\n";
my $expected = $normal_data . $sig;

{
    # test the filtering of the mod_perl response handler
    my $location = '/TestFilter__out_str_reverse';
    my $response = POST_BODY $location, content => $reversed_data;
    ok t_cmp($response, $expected, "reverse filter");
}

{
    # test the filtering of the non-mod_perl response handler (file)
    my $location = '/filter/reverse.txt';
    my $response = GET_BODY $location;
    $response =~ s/\r//g;
    ok t_cmp($response, $expected, "reverse filter");
}
