# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCompat::apache_util;

# Apache::Util compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache2::compat ();
use Apache::Constants qw(OK);

my %string_size = (
    '-1'            => "    -",
    0               => "   0k",
    42              => "   1k",
    42_000          => "  41k",
    42_000_000      => "40.1M",
    42_000_000_000  => "40054M",
);

# list of platforms on which C (not Perl) crypt() is supported
# XXX: add other platforms that are known to have crypt
my %crypt_supported = map {$_ => 1} qw(linux);

my $crypt_ok = $crypt_supported{lc $^O} ? 1 : 0;

my $locale = $ENV{LANG} || $ENV{LC_TIME} || '';
# XXX: will any en_XXX work with http_parse?
# XXX: should we set $ENV{LANG} to en_US instead of skipping?
my $parse_time_ok = $locale =~ /^en_/ ? 1 : 0;

sub handler {
    my $r = shift;

    plan $r, tests => 12 + $parse_time_ok*1 + $crypt_ok*2;

    $r->send_http_header('text/plain');

    # size_string()
    {
        while (my ($k, $v) = each %string_size) {
            ok t_cmp($v, Apache::Util::size_string($k));
        }
    }

    # escape_uri(), escape_path(), unescape_uri()
    my $uri = "http://foo.com/a file.html";
    (my $esc_uri = $uri) =~ s/ /\%20/g;
    my $uri2 = $uri;

    $uri  = Apache::Util::escape_uri($uri);
    $uri2 = Apache::Util::escape_path($uri2, $r->pool);

    ok t_cmp($uri, $esc_uri, "Apache::Util::escape_uri");
    ok t_cmp($uri2, $esc_uri, "Apache::Util::escape_path");

    ok t_cmp(Apache::Util::unescape_uri($uri2),
             Apache2::URI::unescape_url($uri),
             "Apache2::URI::unescape_uri vs Apache::Util::unescape_uri");

    ok t_cmp($uri2,
             $uri,
             "Apache2::URI::unescape_uri vs Apache::Util::unescape_uri");

    # escape_html()
    my $html = '<p>"hi"&foo</p>';
    my $esc_html = '&lt;p&gt;&quot;hi&quot;&amp;foo&lt;/p&gt;';

    ok t_cmp(Apache::Util::escape_html($html), $esc_html,
             "Apache2::Util::escape_html");


    # ht_time(), parsedate()
    my $time = time;
    Apache2::compat::override_mp2_api('Apache2::Util::ht_time');
    my $fmtdate = Apache2::Util::ht_time($time);
    Apache2::compat::restore_mp2_api('Apache2::Util::ht_time');

    ok t_cmp($fmtdate, $fmtdate, "Apache::Util::ht_time");

    if ($parse_time_ok) {
        my $ptime = Apache::Util::parsedate($fmtdate);
        ok t_cmp($ptime, $time, "Apache::Util::parsedate");
    }

    if ($crypt_ok) {
        # not all platforms support C-level crypt
        my $hash = "aX9eP53k4DGfU";
        ok t_cmp(Apache::Util::validate_password("dougm", $hash), 1);
        ok t_cmp(Apache::Util::validate_password("mguod", $hash), 0);
    }

    OK;
}

1;

__END__
PerlOptions +GlobalRequest
