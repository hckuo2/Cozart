# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::read3;

# extra tests in addition to TestApache::read

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);

my $expected = "foobar"x2000;

sub handler {
    my $r = shift;

    # test to read data up to end of file is signaled
    my $data = '';
    my $where = 0;
    my $len;
    do {
        $len = $r->read($data, 100, $where);
        $where += $len;
    } while ($len > 0);

    # only print the plan out after reading to avoid chances of a deadlock
    # see http://mail-archives.apache.org/mod_mbox/perl-dev/201408.mbox/%3C20140809104131.GA3670@estella.local.invalid%3E
    plan $r, tests => 1;

    ok t_cmp($data, $expected, "reading up to end of file");

    Apache2::Const::OK;
}
1;

