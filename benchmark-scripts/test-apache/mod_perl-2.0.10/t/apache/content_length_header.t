# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 12 * 2 + 3;

my $location = "/TestApache__content_length_header";

# 1. because Apache proclaims itself governor of the C-L header via
# the C-L filter (ap_content_length_filter at
# httpd-2.0/server/protocol.c), test whether GET and HEAD behave the
# same wrt C-L under varying circumstances.  for the most part GET
# and HEAD should behave exactly the same.  however, when Apache
# sees a HEAD request with a C-L header of zero it takes special
# action and removes the C-L header.  this is done to protect against
# handlers that called r->header_only (which was ok in 1.3 but is
# not in 2.0).  So, GET and HEAD behave the same except when the
# content handler (plus filters) end up sending no content.  see
# the lengthy comments in ap_http_header_filter in http_protocol.c.
#
# for more discussion on
# why it is important to get HEAD requests right, see these threads
# from the mod_perl list
#   http://marc.theaimsgroup.com/?l=apache-modperl&m=108647669726915&w=2
#   http://marc.theaimsgroup.com/?t=109122984600001&r=1&w=2
# as well as this bug report from mozilla, which shows how they
# are using HEAD requests in the wild
#   http://bugzilla.mozilla.org/show_bug.cgi?id=245447

foreach my $method (qw(GET HEAD)) {

    no strict qw(refs);

    {
        # if the response handler sends no data, and sets no C-L header,
        # the client doesn't get C-L header at all.
        #
        # in 2.0 GET requests get a C-L of zero, while HEAD requests do
        # not due to special processing.
        my $uri = $location;
        my $res = $method->($uri);

        my $cl      = 0;
        my $head_cl = undef;

        ok t_cmp $res->code, 200, "$method $uri code";
        ok t_cmp ($res->header('Content-Length'),
                  $method eq 'GET' ? $cl : $head_cl,
                  "$method $uri C-L header");
        ok t_cmp $res->content, "", "$method $uri content";
    }

    {
        # if the response handler sends no data and sets C-L header,
        # the client should receive the set content length.  in 2.1
        # this is the way it happens.  see protocol.c -r1.150 -r1.151
        #
        # in 2.0 the client doesn't get C-L header for HEAD requests
        # due to special processing, and GET requests get a calculated
        # C-L of zero.
        my $uri = "$location?set_content_length";
        my $res = $method->($uri);

        my $cl      = 0;
        my $head_cl;

        ## 2.2.1, 2.0.56, 2.0.57 were not released
        ## but we use the versions the changes went into
        ## to protect against wierd SVN checkout building.
        ## XXX: I'm starting to think this test is more
        ## trouble then its worth.
        if (have_min_apache_version("2.2.1")) {
          $head_cl = 25;
        }
        elsif (have_min_apache_version("2.2.0")) {
          # $head_cl = undef; # avoid warnings
        }
        elsif (have_min_apache_version("2.0.56")) {
          $head_cl = 25;
        }
        else {
          # $head_cl = undef; # avoid warnings
        }

        ok t_cmp $res->code, 200, "$method $uri code";
        ok t_cmp ($res->header('Content-Length'),
                  $method eq 'GET' ? $cl : $head_cl,
                  "$method $uri C-L header");
        ok t_cmp $res->content, "", "$method $uri content";
    }

    {
        # if the response handler sends data, and sets no C-L header,
        # the client doesn't get C-L header.
        my $uri = "$location?send_body";
        my $res = $method->($uri);
        ok t_cmp $res->code, 200, "$method $uri code";
        ok t_cmp $res->header('Content-Length'), undef,
            "$method $uri C-L header";

        my $content = $method eq 'GET' ? 'This is a response string' : '';
        ok t_cmp $res->content, $content, "$method $uri content";
    }

    {
        # if the response handler sends data (e.g. one char string), and
        # sets C-L header, the client gets the C-L header
        my $uri = "$location?send_body+set_content_length";
        my $res = $method->($uri);
        ok t_cmp $res->code, 200, "$method $uri code";
        ok t_cmp $res->header('Content-Length'), 25,
            "$method $uri C-L header";

        my $content = $method eq 'GET' ? 'This is a response string' : '';
        ok t_cmp $res->content, $content, "$method $uri content";
    }
}

# 2. even though the spec says that content handlers should send an
# identical response for GET and HEAD requests, some folks try to
# avoid the overhead of generating the response body, which Apache is
# going to discard anyway for HEAD requests. The following discussion
# assumes that we deal with a HEAD request.
#
# When Apache sees EOS and no headers and no response body were sent,
# ap_content_length_filter (httpd-2.0/server/protocol.c) sets C-L to
# 0. Later on ap_http_header_filter
# (httpd-2.0/modules/http/http_protocol.c) removes the C-L header for
# the HEAD requests
#
# the workaround is to force the sending of the response headers,
# before EOS was sent. The simplest solution is to use rflush():
#
# if ($r->header_only) { # HEAD
#     $body_len = calculate_body_len();
#     $r->set_content_length($body_len);
#     $r->rflush;
# }
# else {                 # GET
#     # generate and send the body
# }
#
# now if the handler sets the C-L header it'll be delivered to the
# client unmodified.

{
    # if the response handler sends data (e.g. one char string), and
    # sets C-L header, the client gets the C-L header
    my $uri = "$location?head_no_body+set_content_length";
    my $res = HEAD $uri;
    ok t_cmp $res->code, 200, "HEAD $uri code";
    ok t_cmp $res->header('Content-Length'), 25, "HEAD $uri C-L header";
    ok t_cmp $res->content, '', "HEAD $uri content";
}
