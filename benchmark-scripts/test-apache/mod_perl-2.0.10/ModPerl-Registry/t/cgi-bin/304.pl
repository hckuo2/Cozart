# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

# manually handle 'If-Modified-Since' requests

use APR::Date ();
use Apache2::Util ();
use Apache2::RequestRec ();

use constant FMT => '%a, %d %b %Y %H:%M:%S %Z';
use constant GMT => 1;
use Apache2::Const -compile => qw(HTTP_NOT_MODIFIED);

my $last_modified = "Sun, 29 Oct 2000 15:43:29 GMT";

my $r = shift;

my $if_modified_since = $r->headers_in->{'If-Modified-Since'};

my $status = 200;
my $body   = '<html><head></head><body>Test</body></html>';

#APR::Date::parse_http may fail
my $if_modified_since_secs =
    ($if_modified_since && APR::Date::parse_http($if_modified_since)) || 0;
my $last_modified_secs = APR::Date::parse_http($last_modified);

#warn "If-Modified-Since      $if_modified_since\n";
#warn "last_modified_secs     $last_modified_secs\n";
#warn "if_modified_since_secs $if_modified_since_secs\n\n";

if ($last_modified_secs < $if_modified_since_secs) {
    $status = Apache2::Const::HTTP_NOT_MODIFIED;
    $body   = '';
}

my $date = Apache2::Util::ht_time($r->pool, $r->request_time, FMT, GMT);

print <<HEADERS;
Status: $status
Date: $date
Server: Apache/2.0.47
Connection: close
Last-Modified: $last_modified
Content-Type: text/html; charset=iso-8859-1

HEADERS

print $body if length $body;
