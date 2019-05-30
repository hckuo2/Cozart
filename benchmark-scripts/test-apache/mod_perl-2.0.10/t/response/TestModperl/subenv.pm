# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::subenv;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use APR::Table ();

use Apache::Test;

use Apache2::Const -compile => 'OK';

sub handler {

    my $r = shift;

    plan $r, tests => 31;

    # subprocess_env in void context with arguments does
    # nothing to %ENV
    {
        my $env = $r->subprocess_env;

        my $key = 'ONCE';

        ok_false($r, $key);

        $r->subprocess_env($key => 1); # void context but with args

        ok_true($r, $key);

        ok ! $ENV{$key};               # %ENV not populated yet
    }

    # subprocess_env in void context with no arguments
    # populates the same as +SetEnv
    {
        my $env = $r->subprocess_env;

        my $key = 'REMOTE_ADDR';

        ok_false($r, $key);   # still not not there yet

        ok ! $ENV{$key};      # %ENV not populated yet

        $r->subprocess_env;   # void context with no arguments

        ok_true($r, $key);

        ok $ENV{$key};        # mod_cgi emulation
    }

    # handlers can use a void context more than once to force
    # population of %ENV with new table entries
    {
        my $env = $r->subprocess_env;

        my $key = 'AGAIN';

        $env->set($key => 1);      # new table entry

        ok_true($r, $key);

        ok ! $ENV{$key};           # shouldn't affect %ENV yet

        $r->subprocess_env;        # now called in in void context twice

        ok $ENV{$key};             # so %ENV is populated with new entry
    }

    {
        my $env = $r->subprocess_env; # table may have been overlayed

        my $key = 'FOO';

        $env->set($key => 1);         # direct call to set()

        ok_true($r, $key);

        ok ! $ENV{$key};              # shouldn't affect %ENV

        $r->subprocess_env($key => undef);

        ok_false($r, $key);           # removed

        $r->subprocess_env($key => 1);

        ok_true($r, $key);            # reset

        ok ! $ENV{$key};              # still shouldn't affect %ENV
    }

    Apache2::Const::OK;
}

sub ok_true {
    my ($r, $key) = @_;

    my $env = $r->subprocess_env;
    ok $env->get($key);
    ok $env->{$key};
    ok $r->subprocess_env($key);
}

sub ok_false {
    my ($r, $key) = @_;

    my $env = $r->subprocess_env;
    ok ! $env->get($key);
    ok ! $env->{$key};
    ok ! $r->subprocess_env($key);
}

1;
__END__
PerlOptions -SetupEnv

