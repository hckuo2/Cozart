# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::stacked_handlers2;

# this test exercises the execution of the stacked handlers
# connection, translation, authen, authz, type, and response
# phases should end for the first handler that returns OK

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Filter ();

use ModPerl::Util ();

use APR::Table;

use Apache2::Const -compile => qw(OK DECLINED AUTH_REQUIRED SERVER_ERROR);

sub ok {

    callback(shift);

    return Apache2::Const::OK;
}

sub ok_authen {

    my $r = shift;
    callback($r);

    $r->user("user");
    $r->ap_auth_type("Basic");

    return Apache2::Const::OK;
}

sub declined {

    callback(shift);

    return Apache2::Const::DECLINED;
}

sub auth_required {

    callback(shift);

    return Apache2::Const::AUTH_REQUIRED;
}

sub server_error {

    callback(shift);

    return Apache2::Const::SERVER_ERROR;
}

sub push_handlers {

    my $r = shift;

    $r->push_handlers(PerlFixupHandler => \&ok);

    callback($r);

    return Apache2::Const::OK;
}

sub callback {

    my $obj = shift;

    my ($r, $callback);

    if ($obj->isa('Apache2::Filter')) {
        $r = $obj->r;
        $callback = 'PerlOutputFilterHandler';
    }
    else {
        $r = $obj
    }

    $callback ||= ModPerl::Util::current_callback;

    my $count = $r->notes->get($callback) || 0;

    $r->notes->set($callback, ++$count);
}

sub handler {

    my $r = shift;

    $r->content_type('text/plain');

    callback($r);

    foreach my $callback (qw(PerlPostReadRequestHandler
                             PerlTransHandler
                             PerlMapToStorageHandler
                             PerlHeaderParserHandler
                             PerlAccessHandler
                             PerlAuthenHandler
                             PerlAuthzHandler
                             PerlTypeHandler
                             PerlFixupHandler
                             PerlResponseHandler)) {

        my $count = $r->notes->get($callback) || 0;

        $r->print("ran $count $callback handlers\n");
    }

    return Apache2::Const::OK;
}

sub passthru {
    my $filter = shift;

    unless ($filter->ctx) {
       callback($filter);
       $filter->ctx({seen => 1});
    }

    while ($filter->read(my $buffer, 1024)) {
        $filter->print($buffer);
    }

    # this should be ignored?
    Apache2::Const::OK;
}

sub filter {
    my $filter = shift;

    unless ($filter->ctx) {
        callback($filter);
        $filter->ctx({seen => 1});
    }

    while ($filter->read(my $buffer, 1024)) {
        $filter->print($buffer);
    }

    if ($filter->seen_eos) {
        my $count = $filter->r->notes->get('PerlOutputFilterHandler') || 0;

        $filter->print("ran $count PerlOutputFilterHandler handlers\n");
    }

    # this should be ignored?
    Apache2::Const::OK;
}

1;
__DATA__
# create a new virtual host so we can test (almost all) all the hooks
<NoAutoConfig>
<VirtualHost TestHooks::stacked_handlers2>

    PerlModule TestHooks::stacked_handlers2

    # all 2 run
    PerlPostReadRequestHandler TestHooks::stacked_handlers2::ok TestHooks::stacked_handlers2::ok

    # 1 run, 1 left behind
    PerlTransHandler TestHooks::stacked_handlers2::ok TestHooks::stacked_handlers2::server_error

    # 1 run, 1 left behind
    PerlMapToStorageHandler TestHooks::stacked_handlers2::ok TestHooks::stacked_handlers2::server_error

    <Location /TestHooks__stacked_handlers2>
        # all 4 run
        PerlHeaderParserHandler TestHooks::stacked_handlers2::ok TestHooks::stacked_handlers2::declined
        PerlHeaderParserHandler TestHooks::stacked_handlers2::declined TestHooks::stacked_handlers2::ok

        # all 2 run
        PerlAccessHandler TestHooks::stacked_handlers2::ok TestHooks::stacked_handlers2::ok

        # 2 run, 1 left behind
        PerlAuthenHandler TestHooks::stacked_handlers2::declined TestHooks::stacked_handlers2::ok_authen
        PerlAuthenHandler TestHooks::stacked_handlers2::auth_required

        # 2 run, 1 left behind
        PerlAuthzHandler TestHooks::stacked_handlers2::declined TestHooks::stacked_handlers2::ok
        PerlAuthzHandler TestHooks::stacked_handlers2::auth_required

        # 1 run, 1 left behind
        PerlTypeHandler  TestHooks::stacked_handlers2::ok TestHooks::stacked_handlers3::server_error

        # all 4 run
        PerlFixupHandler TestHooks::stacked_handlers2::ok TestHooks::stacked_handlers2::ok
        PerlFixupHandler TestHooks::stacked_handlers2::push_handlers

        # 2 run, 2 left behind
        PerlResponseHandler TestHooks::stacked_handlers2::declined TestHooks::stacked_handlers2
        PerlResponseHandler TestHooks::stacked_handlers2::ok TestHooks::stacked_handlers2::server_error

        SetHandler modperl
        AuthType Basic
        Require valid-user

        PerlOutputFilterHandler TestHooks::stacked_handlers2::passthru TestHooks::stacked_handlers2::filter
    </Location>

</VirtualHost>
</NoAutoConfig>
