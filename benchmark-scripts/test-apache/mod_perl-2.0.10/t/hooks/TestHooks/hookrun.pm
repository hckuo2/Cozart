# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::hookrun;

# this test runs all Apache phases from within the very first http
# phase

# XXX: may be improve the test to do a full-blown test, where each
# phase does something useful.

# see also TestProtocol::pseudo_http

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::HookRun ();
use APR::Table ();
use ModPerl::Util ();

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache2::Const -compile => qw(OK DECLINED DONE SERVER_ERROR);

my $path = '/' . Apache::TestRequest::module2path(__PACKAGE__);

my @phases = qw(
    PerlPostReadRequestHandler
    PerlTransHandler
    PerlMapToStorageHandler
    PerlHeaderParserHandler
    PerlAccessHandler
    PerlAuthenHandler
    PerlAuthzHandler
    PerlTypeHandler
    PerlFixupHandler
    PerlResponseHandler
    PerlLogHandler
);

sub post_read_request {
    my $r = shift;
    my $rc;

    $r->push_handlers(PerlTransHandler        => \&any);
    $r->push_handlers(PerlMapToStorageHandler => \&any);
    $r->push_handlers(PerlHeaderParserHandler => \&any);
    $r->push_handlers(PerlAccessHandler       => \&any);
    $r->push_handlers(PerlAuthenHandler       => \&any);
    $r->push_handlers(PerlAuthzHandler        => \&any);
    $r->push_handlers(PerlTypeHandler         => \&any);
    $r->push_handlers(PerlFixupHandler        => \&any);
    $r->push_handlers(PerlLogHandler          => \&any);

    any($r); # indicate that the post_read_request phase was run

    # for the full Apache logic for running phases starting from
    # post_read_request and ending with fixup see
    # ap_process_request_internal in httpd-2.0/server/request.c

    $rc = $r->run_translate_name;
    return $rc unless $rc == Apache2::Const::OK or $rc == Apache2::Const::DECLINED;

    $rc = $r->run_map_to_storage;
    return $rc unless $rc == Apache2::Const::OK or $rc == Apache2::Const::DECLINED;

    # this must be run all a big havoc will happen in the following
    # phases
    $r->location_merge($path);

    $rc = $r->run_header_parser;
    return $rc unless $rc == Apache2::Const::OK or $rc == Apache2::Const::DECLINED;

    my $args = $r->args || '';
    if ($args eq 'die') {
        $r->die(Apache2::Const::SERVER_ERROR);
        return Apache2::Const::DONE;
    }

    $rc = $r->run_access_checker;
    return $rc unless $rc == Apache2::Const::OK or $rc == Apache2::Const::DECLINED;

    $rc = $r->run_auth_checker;
    return $rc unless $rc == Apache2::Const::OK or $rc == Apache2::Const::DECLINED;

    $rc = $r->run_check_user_id;
    return $rc unless $rc == Apache2::Const::OK or $rc == Apache2::Const::DECLINED;

    $rc = $r->run_type_checker;
    return $rc unless $rc == Apache2::Const::OK or $rc == Apache2::Const::DECLINED;

    $rc = $r->run_fixups;
    return $rc unless $rc == Apache2::Const::OK or $rc == Apache2::Const::DECLINED;

    # $r->run_handler is called internally by $r->invoke_handler,
    # invoke_handler sets all kind of filters, and does a few other
    # things but it's possible to call $r->run_handler, bypassing
    # invoke_handler
    $rc = $r->invoke_handler;
    return $rc unless $rc == Apache2::Const::OK or $rc == Apache2::Const::DECLINED;

    $rc = $r->run_log_transaction;
    return $rc unless $rc == Apache2::Const::OK or $rc == Apache2::Const::DECLINED;

    return Apache2::Const::DONE;

    # Apache runs ap_finalize_request_protocol on return of this
    # handler
}

sub any {
    my $r = shift;

    my $callback = ModPerl::Util::current_callback();

    debug "running $callback\n";
    $r->notes->set($callback => 1);

    # unset the callback that was already run
    $r->set_handlers($callback => []);

    Apache2::Const::OK;
}

sub response {
    my $r = shift;

    my @pre_response = (@phases)[0..($#phases-2)];
    plan tests => scalar(@pre_response);

    for my $phase (@pre_response) {
        my $note = $r->notes->get($phase);
        $r->print("$phase:$note\n");
    }

    Apache2::Const::OK;
}

1;
__END__
<NoAutoConfig>
<VirtualHost TestHooks::hookrun>
    PerlModule                 TestHooks::hookrun
    PerlPostReadRequestHandler TestHooks::hookrun::post_read_request
    <Location /TestHooks__hookrun>
        SetHandler modperl
        PerlResponseHandler    TestHooks::hookrun::response

        AuthName modperl
        AuthType none
        Require valid-user
    </Location>
</VirtualHost>
</NoAutoConfig>
