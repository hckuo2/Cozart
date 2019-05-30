# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use ExtUtils::testlib;
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

# -compile puts constants into the Apache2:: namespace
use Apache2::Const -compile => qw(:http :common :mpmq :proxy
                                  TAKE23 &OPT_EXECCGI
                                  DECLINE_CMD DIR_MAGIC_TYPE
                                  CRLF);

# without -compile, constants are in the
# caller namespace.  also defaults to :common
use Apache2::Const;

plan tests => 18;

ok t_cmp(REDIRECT, 302, 'REDIRECT');

ok t_cmp(AUTH_REQUIRED, 401, 'AUTH_REQUIRED');

ok t_cmp(OK, 0, 'OK');

ok t_cmp(Apache2::Const::OK, 0, 'Apache2::Const::OK');

ok t_cmp(Apache2::Const::DECLINED, -1, 'Apache2::Const::DECLINED');

ok t_cmp(Apache2::Const::HTTP_GONE, 410, 'Apache2::Const::HTTP_GONE');

ok t_cmp(Apache2::Const::DIR_MAGIC_TYPE,
         'httpd/unix-directory',
         'Apache2::Const::DIR_MAGIC_TYPE');

ok t_cmp(Apache2::Const::MPMQ_MAX_SPARE_DAEMONS,
         9,
         'Apache2::Const::MPMQ_MAX_SPARE_DAEMONS');

ok t_cmp(Apache2::Const::PROXYREQ_REVERSE,
         2,
         'Apache2::Const::PROXYREQ_REVERSE');

# the rest of the tests don't fit into the t_cmp() meme
# for one reason or anothre...

print "testing Apache2::Const::OPT_EXECCGI is defined\n";
ok defined Apache2::Const::OPT_EXECCGI;

print "testing Apache2::Const::DECLINE_CMD\n";
ok Apache2::Const::DECLINE_CMD eq "\x07\x08";

# try and weed out EBCDIC - this is the test httpd uses
if (chr(0xC1) eq 'A') {
    print "testing Apache2::Const::CRLF (EBCDIC)\n";
    ok Apache2::Const::CRLF eq "\r\n";
}
else {
    print "testing Apache2::Const::CRLF (ASCII)\n";
    ok Apache2::Const::CRLF eq "\015\012";

}

print "testing M_GET not yet defined\n";
ok ! defined &M_GET;

Apache2::Const->import('M_GET');

print "testing M_GET now defined\n";
ok defined &M_GET;

for (qw(BOGUS :bogus -foobar)) {

    eval { Apache2::Const->import($_) };

    print "testing bogus import $_\n";
    ok $@;
}

print "testing explicit call to compile()\n";
eval { Apache2::Const::compile() };

ok $@;
