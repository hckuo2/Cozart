# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::dir_config;

use strict;
use warnings FATAL => 'all';

use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::RequestUtil ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 15;

    #Apache2::RequestRec::dir_config tests

    # this test doesn't test all $r->dir_config->*(), since
    # dir_config() returns a generic APR::Table which is tested in
    # apr/table.t.

    # object test
    my $dir_config = $r->dir_config;
    ok defined $dir_config && ref($dir_config) eq 'APR::Table';

    # make sure trying to get something that's not defined
    # doesn't blow up
    my $undef = $r->dir_config('EDOESNOTEXIST');

    ok t_cmp($undef, undef,
             'no PerlSetVar to get data from');

    # PerlAddVar ITERATE2 test
    {
        my $key = make_key('1');
        my @received = $dir_config->get($key);
        my @expected = qw(1_SetValue 2_AddValue 3_AddValue 4_AddValue);

        ok t_cmp(\@received, \@expected,
                 'PerlAddVar ITERATE2');
    }

    # sub-section inherits from super-section if it doesn't override it
    {
        my $key = make_key('_set_in_Base');
        ok t_cmp($r->dir_config($key),
                 'BaseValue',
                 "sub-section inherits from super-section " .
                 "if it doesn't override it");
    }

    # sub-section overrides super-section for the same key
    {
        my $key = 'TestModperl__server_rec_Key_set_in_Base';
        ok t_cmp($r->dir_config->get($key), 'SubSecValue',
                 "sub-section overrides super-section for the same key");
    }

    {
        my $key = make_key('0');

        # object interface test in a scalar context (for a single
        # PerlSetVar key)
        ok t_cmp($dir_config->get($key),
                 'SetValue0',
                 "table get() in a scalar context");

        # direct fetch test in a scalar context (for a single
        # PerlSetVar key)
        ok t_cmp($r->dir_config($key),
                 'SetValue0',
                 "direct value fetch in a scalar context");
    }

    # make sure 0 comes through as 0 and not undef
    {
        my $key = 'TestModperl__request_rec_ZeroKey';

        ok t_cmp($r->dir_config($key),
                 0,
                 'table value 0 is not undef');
    }

    # test non-existent key
    {
        my $key = make_key();

        ok t_cmp($r->dir_config($key),
                 undef,
                 "non-existent key");
    }

    # test set interface
    {
        my $key = make_key();
        my $val = "DirConfig";

        $r->dir_config($key => $val);

        ok t_cmp($r->dir_config($key),
                 $val,
                 "set && get");
    }

    # test unset interface
    {
        my $key = make_key();

        $r->dir_config($key => 'whatever');
        $r->dir_config($key => undef);

        ok t_cmp(undef,
                 $r->dir_config($key),
                 "unset");
    }


    #Apache2::ServerUtil::dir_config tests

    my $s = $r->server;

    # this test doesn't test all $s->dir_config->*(), since
    # dir_config() returns a generic APR::Table which is tested in
    # apr/table.t.

    # object test
    $dir_config = $s->dir_config;
    ok defined $dir_config && ref($dir_config) eq 'APR::Table';

    # PerlAddVar ITERATE2 test
    {
        my $key = 'TestModperl__server_rec_Key_set_in_Base';
        my @received = $dir_config->get($key);
        my @expected = qw(1_SetValue 2_AddValue 3_AddValue);

        ok t_cmp(\@received, \@expected,
                 "testing PerlAddVar ITERATE2 in \$s");
    }

    {
        # base server test
        my $bs = Apache2::ServerUtil->server;
        ok t_cmp(($bs && ref($bs)),
                 'Apache2::ServerRec',
                 "base server's object retrieval");

        my $key = 'TestModperl__server_rec_Key_set_in_Base';
        ok t_cmp(scalar ($bs->dir_config->get($key)),
                 '1_SetValue',
                 "read dir_config of the base server");
    }

    Apache2::Const::OK;
}

my $key_base = "TestModperl__request_rec_Key";
my $counter  = 0;

sub make_key {
    return $key_base .
        (defined $_[0]
            ? $_[0]
            : unpack "H*", pack "n", ++$counter . rand(100));
}
1;
__END__
<Base>
    PerlSetVar TestModperl__request_rec_Key_set_in_Base BaseValue

    PerlSetVar TestModperl__server_rec_Key_set_in_Base 1_SetValue
    PerlAddVar TestModperl__server_rec_Key_set_in_Base 2_AddValue 3_AddValue
</Base>

PerlSetVar TestModperl__request_rec_ZeroKey 0

PerlSetVar TestModperl__request_rec_Key0 SetValue0

PerlSetVar TestModperl__request_rec_Key1 ToBeLost
PerlSetVar TestModperl__request_rec_Key1 1_SetValue
PerlAddVar TestModperl__request_rec_Key1 2_AddValue
PerlAddVar TestModperl__request_rec_Key1 3_AddValue 4_AddValue

PerlSetVar TestModperl__server_rec_Key_set_in_Base SubSecValue
