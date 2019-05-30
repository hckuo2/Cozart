# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::read2;

# extra tests in addition to TestApache::read

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);

my $expected = "foobar";

sub handler {
    my $r = shift;

    # test the case where the buffer to be filled has set magic
    # attached. which is the case when one passes an non-existing hash
    # entry value. it's not autovivified when passed to the function
    # and it's not undef. running SetMAGIC inside read accomplishes
    # the autovivication in this particular case.
    my $data;
    my $len = $r->read($data->{buffer}, $r->headers_in->{'Content-Length'});

    # only print the plan out after reading to avoid chances of a deadlock
    # see http://mail-archives.apache.org/mod_mbox/perl-dev/201408.mbox/%3C20140809104131.GA3670@estella.local.invalid%3E
    plan $r, tests => 1;

    ok t_cmp($data->{buffer},
             $expected,
             "reading into an autovivified hash entry");

    Apache2::Const::OK;
}
1;

