# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::request_util;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestUtil ();
use Apache2::MPM ();
use Apache2::Log ();
use APR::Pool ();

use Apache2::Const -compile => 'OK';

my %status_lines = (
   200 => '200 OK',
   400 => '400 Bad Request',
   500 => '500 Internal Server Error',
);

sub handler {
    my $r = shift;

    plan $r, tests => (scalar keys %status_lines) + 11;

    # default_type() is gone as of httpd 2.3.2-dev
    ok !defined(&Apache2::RequestRec::default_type) || $r->default_type;

    my $document_root = $r->document_root;

    ok $document_root;

    if (!Apache2::MPM->is_threaded) {
        my $path_orig = my $path = '/tmp/foo';
        ok t_cmp($document_root, $r->document_root($path));
        # make sure that the new docroot string is copied internally,
        # and later manipulations of the passed scalar don't affect it
        $path .= "suffix";
        ok t_cmp($path_orig, $r->document_root($document_root));
    }
    else {
        eval { $r->document_root('/tmp/foo') };
        ok t_cmp($@, qr/Can't run.*in the threaded env/,
                 "document_root is read-only under threads");
        ok 1;
    }

    ok $r->get_server_name;

    ok $r->get_server_port;

    ok $r->get_limit_req_body || 1;

    ok $r->is_initial_req;

    my $sig = $r->psignature("Here is the sig: ");
    t_debug $sig;
    ok $sig;

    my $pattern =
        qr!(?s)GET /TestAPI__request_util.*Host:.*200 OK.*Content-Type:!;

    ok t_cmp($r->as_string,
             $pattern,
             "test for the request_line, host, status, and few " .
             "headers that should always be there");

    while (my ($code, $line) = each %status_lines) {
        ok t_cmp(Apache2::RequestUtil::get_status_line($code),
                 $line,
                 "Apache2::RequestUtil::get_status_line($code)");
    }

    if (Apache2::MPM->is_threaded) {
        eval { $r->child_terminate() };
        ok t_cmp($@, qr/Can't run.*in a threaded mpm/, "child_terminate");
    }
    else {
        t_server_log_error_is_expected();
        ok $r->child_terminate() || 1;
        $r->pool->cleanup_register(
            sub {
                my $r = shift;
                $r->log_error("Process $$ terminates itself\n");
            }, $r);
    }

    Apache2::Const::OK;
}

1;
