# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::util;

# Apache2::Util tests

use strict;
use warnings FATAL => 'all';

# to fully test this test the following locale settings need to be run:
#
# some /^en_/ locale, e.g. /^en_GB*
# LC_CTYPE=en_GB.UTF-8 LC_TIME=en_GB.UTF-8 t/TEST -verbose apache/util.t
# LC_CTYPE=en_GB       LC_TIME=en_GB       t/TEST -verbose apache/util.t
#
# some non-/^en_/ locale, e.g. ru_RU
# LC_CTYPE=ru_RU.UTF-8 LC_TIME=ru_RU.UTF-8 t/TEST -verbose apache/util.t
# LC_CTYPE=ru_RU       LC_TIME=ru_RU       t/TEST -verbose apache/util.t

# regex matching (LC_CTYPE) of strftime-like (LC_TIME) strings
use locale;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Util ();
use APR::Date ();

use Apache::TestUtil;
use Apache::Test;

use Apache2::Const -compile => 'OK';

# those are passed via PerlPassEnv
my $locale = $ENV{LC_TIME} || '';

my $parse_time_ok  = $locale =~ /^en_/   ? 1 : 0;
my $locale_is_utf8 = $locale =~ /UTF-8$/ ? 1 : 0;

sub handler {
    my $r = shift;

    plan $r, tests => 8;

    # ht_time
    {
        my $time = time;
        my $fmt = "%a, %d %b %Y %H:%M:%S %Z";
        my $fmtdate;

        $fmtdate = Apache2::Util::ht_time($r->pool);
        time_cmp($fmtdate, $time,
                 'Apache2::Util::ht_time($pool)', 0);

        $fmtdate = Apache2::Util::ht_time($r->pool, $time);
        time_cmp($fmtdate, $time,
                 'Apache2::Util::ht_time($pool, $time)', 1);

        $fmtdate = Apache2::Util::ht_time($r->pool, $time, $fmt);
        time_cmp($fmtdate, $time,
                 'Apache2::Util::ht_time($pool, $time, $fmt)', 1);

        my $gmt = 0;
        $fmtdate = Apache2::Util::ht_time($r->pool, $time, $fmt, $gmt);
        time_cmp($fmtdate, $time,
                 'Apache2::Util::ht_time($pool, $time, $fmt, $gmt)', 0);
    }

    # escape_path
    {
        my ($uri, $received, $expected);

        $uri = "a 'long' file?.html";
        ($expected = $uri) =~ s/([\s?;])/sprintf "%%%x", ord $1/ge;

        $received = Apache2::Util::escape_path($uri, $r->pool);
        ok t_cmp $received, $expected,
            "Apache2::Util::escape_path / partial=1 / default";

        $received = Apache2::Util::escape_path($uri, $r->pool, 1);
        ok t_cmp $received, $expected,
            "Apache2::Util::escape_path / partial=1 / explicit";

        $received = Apache2::Util::escape_path($uri, $r->pool, 0);
        ok t_cmp $received, $expected,
            "Apache2::Util::escape_path / partial=0";

        $uri = "a 'long' file?.html:";
        ($expected = $uri) =~ s/([\s?;])/sprintf "%%%x", ord $1/ge;
        # XXX: why does it prepend ./ only if it sees : or :/?
        $expected = "./$expected";

        $received = Apache2::Util::escape_path($uri, $r->pool, 0);
        ok t_cmp $received, $expected,
            "Apache2::Util::escape_path / partial=0 / ./ prefix ";

    }

    Apache2::Const::OK;
}

my $fmtdate_re = qr/^\w+, \d\d \w+ \d\d\d\d \d\d:\d\d:\d\d/;
sub time_cmp {
    my ($fmtdate, $time, $comment, $exact_match) = @_;

    if ($parse_time_ok && $exact_match) {
        my $ptime = APR::Date::parse_http($fmtdate);
        t_debug "fmtdate: $fmtdate";
        ok t_cmp $ptime, $time, $comment;
    }
    else {
        if ($locale_is_utf8) {
            if (have_min_perl_version(5.008)) {
                require Encode;
                # perl doesn't know yet that $fmtdate is a utf8 string
                $fmtdate = Encode::decode_utf8($fmtdate);
            }
            else {
                skip "Skip locale $locale needs perl 5.8.0+", 0;
                return;
            }
        }
        ok t_cmp $fmtdate, $fmtdate_re, $comment;
    }
}

1;

__END__

