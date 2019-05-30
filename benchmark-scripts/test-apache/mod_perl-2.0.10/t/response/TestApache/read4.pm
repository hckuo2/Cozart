# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::read4;

# extra tests in addition to TestApache::read

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);

my @expected = ("123foo",
                "123456".("\0"x(1000-length("123456")))."bar",
                "123f",
                "23f\0\0o",
                qr/\bread-?only\b/,
                $^V,
                "ARo",
                qr/\bread-?only\b/,
                ".........",
                # Reading into $1 (the test above) eats up input since perl
                # 5.10. This was also the version that blessed $^V as a
                # "version" object.
                (ref $^V ? "\0\0ar" : "\0\0bar"),
                "12",
                "");

sub X::TIESCALAR {bless []=>'X'}
sub X::FETCH {$_[0]->[0]}
sub X::STORE {$_[0]->[0]=$_[1]}

sub handler {
    my $r = shift;

    plan $r, tests => 12;
    my $test = 0;

    # we get the string "foobarfoobar" as input here

    # this test consumes 3 bytes
    my $data = 12345;
    $r->read($data, 3, -2);
    ok t_cmp($data, $expected[$test++], "negative offset");


    # "barfoobar" still to be read
    $data = 123456;
    # now $data is a valid IV but has a PV buffer assigned.
    # read() has to convert to a valid PV.
    $r->read($data, 3, 1000);
    ok t_cmp($data, $expected[$test++], "offset > length of string");


    # "foobar" still to be read
    $r->read($data, 1, 3);
    ok t_cmp($data, $expected[$test++], "shrink string");


    # "oobar" still to be read
    substr($data, 0, 1) = '';     # set the OOK flag (PV starts at offset 1)
    $r->read($data, 1, 5);
    ok t_cmp($data, $expected[$test++], "PV with OOK flag set");


    # "obar" still to be read
    # this test dies BEFORE reading anything
    eval {$r->read($^V, 1)};
    ok t_cmp($@, $expected[$test++], "read-only \$^V");
    ok t_cmp($^V, $expected[$test++], "\$^V untouched");


    # "obar" still to be read
    $data=[];
    eval {$r->read($data, 1, 2)};
    ok t_cmp($data, $expected[$test++], "passing an RV as data");


    # "bar" still to be read
    # this test consumes the "b" although it should not
    "........."=~/(.*)/;
    eval {$r->read($1, 1)};
    my $x="$1";                   # just in case
    ok t_cmp($@, $expected[$test++], "read-only \$1");
    ok t_cmp($x, $expected[$test++], "\$1 untouched");


    # "ar" still to be read
    # now eat up the rest of input
    tie $data, 'X';
    $data='';
    $r->read($data, 100, 2);
    ok t_cmp(tied($data)->[0], $expected[$test++], "read into a tied buffer");

    untie $data;


    # input is empty
    $data=123456;
    $r->read($data, 1000, 2);
    ok t_cmp($data, $expected[$test++], "read at eof");


    # input is empty
    $r->read($data, 1000);
    ok t_cmp($data, $expected[$test++], "repeated read at eof");

    Apache2::Const::OK;
}
1;

