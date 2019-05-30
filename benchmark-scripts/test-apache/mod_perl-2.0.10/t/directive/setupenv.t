# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 3;

my $location = '/TestDirective__setupenv';

my $env = GET_BODY $location;

ok $env;

my %env;

for my $line (split /\n/, $env) {
    next unless $line =~ /=/;
    my ($key, $val) = split /=/, $line, 2;
    $env{$key} = $val || '';
}

ok t_cmp $env{REQUEST_URI}, $location, "testing REQUEST_URI";

{
    # on Win32, some user environment variables, like HOME, may be
    # passed through (via Apache?) if set, while system environment
    # variables are not. so try to find an existing shell variable
    # (that is not passed by Apache) and use it in the test to make
    # sure mod_perl doesn't see it

    my $var;
    for (qw(SHELL USER OS)) {
        $var = $_, last if exists $ENV{$_};
    }

    if (defined $var) {
        ok t_cmp $env{$var}, undef, "env var $var=$ENV{$var} is ".
            "set in shell, but shouldn't be seen inside mod_perl";
    }
    else {
        skip "couldn't find a suitable env var to test against", 0;
    }
}
