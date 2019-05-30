# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

# test internal redirects originating from 'SetHandler modperl' and
# 'SetHandler perl-script' main handlers, and sub-requests handled by
# the handlers of the same and the opposite kind

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $uri = "/TestAPI__internal_redirect";

my %map = (
    "modperl => modperl"         => "${uri}_modperl?uri=${uri}_modperl",
    "perl-script => modperl"     => "${uri}_perl_script?uri=${uri}_modperl",
    "perl-script => perl-script" => "${uri}_perl_script?uri=${uri}_perl_script",
    "modperl => perl-script"     => "${uri}_modperl?uri=${uri}_perl_script",
);

plan tests => scalar keys %map;

while (my ($key, $val) = each %map) {
    my $expected = "internal redirect: $key";
    my $received = GET_BODY_ASSERT $val;
    ok t_cmp($received, $expected);
}
