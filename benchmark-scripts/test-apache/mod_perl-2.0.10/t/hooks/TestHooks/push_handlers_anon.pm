# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::push_handlers_anon;

# in addition to other anon sub handler tests in push_handlers*, here
# we test an anon sub added at the server startup. in order not to mess
# with the rest of the test suite, we run it in its own vhost

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::ServerUtil ();
use APR::Pool ();

use Apache2::Const -compile => qw(OK DECLINED);

use Apache::Test;
use Apache::TestUtil;

sub add_note {
    my $r = shift;

    my $count = $r->notes->get("add_note") || 0;
    $count++;
    $r->notes->set("add_note", $count);
    Apache2::Const::DECLINED;
}

# PerlFixupHandlers added at the server startup should add 3 notes
sub handler {
    my $r = shift;

    plan $r, tests => 1;

    my $count = $r->notes->get("add_note") || 0;
    ok t_cmp $count, 3, "$count callbacks";

    Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
# APACHE_TEST_CONFIG_ORDER 1000
<VirtualHost TestHooks::push_handlers_anon>
    PerlModule            TestHooks::push_handlers_anon
    <Perl >
    my $s = Apache2::PerlSections->server;

    $s->push_handlers(PerlFixupHandler =>
                       sub { &TestHooks::push_handlers_anon::add_note });
    $s->push_handlers(PerlFixupHandler =>
                       \&TestHooks::push_handlers_anon::add_note       );
    $s->push_handlers(PerlFixupHandler =>
                      "TestHooks::push_handlers_anon::add_note"        );
    </Perl>

    <Location /TestHooks__push_handlers_anon>
        SetHandler modperl
        PerlResponseHandler TestHooks::push_handlers_anon
    </Location>
</VirtualHost>
</NoAutoConfig>
