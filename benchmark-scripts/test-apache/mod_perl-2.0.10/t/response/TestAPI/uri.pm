# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::uri;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use APR::Pool ();
use APR::URI ();
use Apache2::URI ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();

use Apache2::Const -compile => 'OK';

my $location = '/' . Apache::TestRequest::module2path(__PACKAGE__);

sub handler {
    my $r = shift;

    plan $r, tests => 24;

    $r->args('query');

    # basic
    {
        my $uri = $r->parsed_uri;

        ok $uri->isa('APR::URI');

        ok t_cmp($uri->path, qr/^$location/, "path");

        my $up = $uri->unparse;
        ok t_cmp($up, qr/^$location/, "unparse");
    }

    # construct_server
    {
        my $server = $r->construct_server;
        ok t_cmp(join(':', $r->get_server_name, $r->get_server_port),
                 $server,
                 "construct_server/get_server_name/get_server_port");
    }
    {
        my $hostname = "example.com";
        my $server = $r->construct_server($hostname);
        ok t_cmp(join(':', $hostname, $r->get_server_port),
                 $server,
                 "construct_server($hostname)");
    }
    {
        my $hostname = "example.com";
        my $port     = "9097";
        my $server = $r->construct_server($hostname, $port);
        ok t_cmp(join(':', $hostname, $port),
                 $server,
                 "construct_server($hostname, $port)");

    }
    {
        my $hostname = "example.com";
        my $port     = "9097";
        my $server = $r->construct_server($hostname, $port, $r->pool->new);
        ok t_cmp(join(':', $hostname, $port),
                 $server,
                 "construct_server($hostname, $port, new_pool)");

    }

    # construct_url
    {
        # if no args are passed then only $r->uri will be included (no
        # query and no fragment fields)
        my $curl = $r->construct_url;
        t_debug("construct_url: $curl");
        t_debug("r->uri: " . $r->uri);
        my $parsed = APR::URI->parse($r->pool, $curl);

        ok $parsed->isa('APR::URI');

        my $up = $parsed->unparse;
        ok t_cmp($up, qr/$location/, "unparse");

        my $path = '/foo/bar';

        $parsed->path($path);

        ok t_cmp($parsed->path, $path, "parsed path");
    }
    {
        # this time include args in the constructed url
        my $fragment = "fragment";
        $r->parsed_uri->fragment($fragment);
        my $curl = $r->construct_url(sprintf "%s?%s", $r->uri, $r->args);
        t_debug("construct_url: $curl");
        t_debug("r->uri: ", $r->uri);
        my $parsed = APR::URI->parse($r->pool, $curl);

        my $up = $parsed->unparse;
        ok t_cmp($up, qr/$location/, 'construct_url($uri)');
        ok t_cmp($parsed->query, $r->args, "args vs query");
    }
    {
        # this time include args and a pool object
        my $curl = $r->construct_url(sprintf("%s?%s", $r->uri, $r->args),
                                     $r->pool->new);
        t_debug("construct_url: $curl");
        t_debug("r->uri: ", $r->uri);
        my $up = APR::URI->parse($r->pool, $curl)->unparse;
        ok t_cmp($up, qr/$location/, 'construct_url($uri, $pool)');
    }

    # segfault test
    {
        # test the segfault in apr < 0.9.2 (fixed on mod_perl side)
        # passing only the /path
        my $parsed = APR::URI->parse($r->pool, $r->uri);
        # set hostname, but not the scheme
        $parsed->hostname($r->get_server_name);
        $parsed->port($r->get_server_port);
        #$parsed->scheme('http');
        my $expected = $r->construct_url;
        my $received = $parsed->unparse;
        t_debug("the real received is: $received");
        # apr < 0.9.2-dev + fix in mpxs_apr_uri_unparse will return
        #    '://localhost.localdomain:8529/TestAPI::uri'
        # apr >= 0.9.2 with internal fix will return
        #    '//localhost.localdomain:8529/TestAPI::uri'
        # so in order to test pre-0.9.2 and post-0.9.2-dev we massage it
        $expected =~ s|^http:||;
        $received =~ s|^:||;
        ok t_cmp($received, $expected,
                 "the bogus url is expected when 'hostname' is set " .
                 "but not 'scheme'");
    }

    # parse_uri
    {
        my $path     = "/foo/bar";
        my $query    = "query";
        my $fragment = "fragment";
        my $newr = Apache2::RequestRec->new($r->connection, $r->pool);
        my $url_string = "$path?$query#$fragment";

        # new request
        $newr->parse_uri($url_string);
        $newr->path_info('/bar');
        ok t_cmp($newr->uri, $path, "uri");
        ok t_cmp($newr->args, $query, "args");
        ok t_cmp($newr->path_info, '/bar', "path_info");

        my $puri = $newr->parsed_uri;
        ok t_cmp($puri->path,     $path,     "path");
        ok t_cmp($puri->query,    $query,    "query");
        ok t_cmp($puri->fragment, $fragment, "fragment");

        #rpath
        ok t_cmp($puri->rpath, '/foo', "rpath");

        my $port = 6767;
        $puri->port($port);
        $puri->scheme('ftp');
        $puri->hostname('perl.apache.org');

        ok t_cmp($puri->port, $port, "port");

        ok t_cmp($puri->unparse,
                 "ftp://perl.apache.org:$port$path?$query#$fragment",
                 "unparse");
    }

    # unescape_url
    {
        my @c = qw(one two three);
        my $url_string = join '%20', @c;

        Apache2::URI::unescape_url($url_string);

        ok $url_string eq "@c";
    }

    Apache2::Const::OK;
}

1;
