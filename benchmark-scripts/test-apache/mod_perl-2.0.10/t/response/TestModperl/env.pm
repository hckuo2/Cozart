# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::env;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 23 + 3 * keys(%ENV);

    my $env = $r->subprocess_env;

    ok $ENV{MODPERL_EXTRA_PL}; #set in t/conf/modperl_extra.pl
    ok $ENV{MOD_PERL};
    ok $ENV{MOD_PERL_API_VERSION};

    ok $ENV{SERVER_SOFTWARE};
    ok $env->get('SERVER_SOFTWARE');

    {
        $ENV{FOO} = 2;
        ok $ENV{FOO} == 2;
        ok $env->get('FOO') == 2;

        $ENV{FOO}++;
        ok $ENV{FOO} == 3;
        ok $env->get('FOO') == 3;

        $ENV{FOO} .= 6;
        ok $ENV{FOO} == 36;
        ok $env->get('FOO') == 36;

        delete $ENV{FOO};
        ok ! $ENV{FOO};
        ok ! $env->get('FOO');
    }

    {
        local %ENV = (FOO => 1, BAR => 2);

        ok $ENV{FOO} == 1;
        ok $env->get('FOO') == 1;

        ok ! $ENV{SERVER_SOFTWARE};
        ok ! $env->get('SERVER_SOFTWARE');
    }

    ok ! $ENV{FOO};
    skip "r->subprocess_env + local() doesnt fully work yet", 1;
    #ok ! $env->get('FOO');

    {
        my $key = 'SERVER_SOFTWARE';
        my $val = $ENV{SERVER_SOFTWARE};
        ok $val;
        ok t_cmp $env->get($key), $val, '$r->subprocess_env->get($key)';
        ok t_cmp $r->subprocess_env($key), $val, '$r->subprocess_env($key)';

        $val = 'BAR';
        $r->subprocess_env($key => $val);
        ok t_cmp $r->subprocess_env($key), $val,
            '$r->subprocess_env($key => $val)';
    }

    # make sure each key can be deleted
    for my $key (sort keys %ENV) {
        eval { delete $ENV{$key}; };
        ok t_cmp($@, '', $key);
        ok t_cmp($ENV{$key}, undef, "ENV{$key} is empty");
        ok t_cmp($env->get($key), undef, "subprocess_env($key) is empty");
    }

    Apache2::Const::OK;
}

1;
__END__
SetHandler perl-script
