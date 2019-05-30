# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::post_utf8;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use APR::Table ();

use TestCommon::Utils ();

use Apache2::Const -compile => 'OK';

my $expected_ascii = "I love you, (why lying?), but I belong to another";
my $expected_utf8  = "\x{042F} \x{0432}\x{0430}\x{0441} \x{043B}\x{044E}" .
    "\x{0431}\x{043B}\x{044E} (\x{043A} \x{0447}\x{0435}\x{043C}\x{0443} " .
    "\x{043B}\x{0443}\x{043A}\x{0430}\x{0432}\x{0438}\x{0442}\x{044C}?),\n" .
    "\x{041D}\x{043E} \x{044F} \x{0434}\x{0440}\x{0443}\x{0433}\x{043E}" .
    "\x{043C}\x{0443} \x{043E}\x{0442}\x{0434}\x{0430}\x{043D}\x{0430};";

sub handler {
    my $r = shift;

#    # visual debug, e.g. in lynx/mozilla
#    $r->content_type("text/plain; charset=utf-8");
#    $r->print("expected: $expected_utf8\n");

    # utf encode/decode was added only in 5.8.0
    # XXX: currently binmode is only available with perlio (used on the
    # server side on the tied/perlio STDOUT)
    plan $r, tests => 2,
        need need_min_perl_version(5.008), need_perl('perlio');

    my $received = TestCommon::Utils::read_post($r) || "";

    # workaround for perl-5.8.0, which doesn't decode correctly a
    # tainted variable
    require ModPerl::Util;
    ModPerl::Util::untaint($received) if $] == 5.008;

    # assume that we know that it's utf8
    require Encode; # since 5.8.0
    $received = Encode::decode('utf8', $received);
    # utf8::decode() doesn't work under -T
    my ($received_ascii, $received_utf8) = split /=/, $received;

    ok t_cmp($received_ascii, $expected_ascii, "ascii");

    ok $expected_utf8 eq $received_utf8;
    # if you want to see the utf8 data run with:
    # t/TEST -trace=debug -v modperl/post_utf8
    # and look for this data in t/logs/error_log
    # needed for sending utf-8 to STDERR for debug
    binmode(STDERR, ':utf8');
    debug "expected: $expected_utf8";
    debug "received: $received_utf8";

    Apache2::Const::OK;
}

1;
__END__
SetHandler perl-script
