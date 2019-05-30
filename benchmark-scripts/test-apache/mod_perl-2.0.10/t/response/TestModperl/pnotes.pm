# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::pnotes;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestUtil ();
use Apache2::ConnectionUtil ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    # make it ok to call ok() here while plan()ing elsewhere
    Apache::Test::init_test_pm($r);

    Test::_reset_globals() if Test->can('_reset_globals');
    $Test::ntest   = 1 + (26 * ($r->args - 1));
    $Test::planned = 26;

    my $c = $r->connection;

    # we call this handler 3 times.
    # $r->pnotes('request') should be unset each time
    # $c->pnotes('connection') should be unset the first
    # time but set the second time due to the keepalive
    # request.  the second request then cleans up after
    # itself, leaving $c->pnotes again unset at the
    # start of the third request
    if ($r->args == 2) {
        ok t_cmp($c->pnotes('connection'),
                 'CSET',
                 '$c->pnotes() persists across keepalive requests');
    }
    else {
        t_debug('testing $c->pnotes is empty');
        ok (! $c->pnotes('connection'));
    }

    # $r->pnotes should be reset each time
    t_debug('testing $r->pnotes is empty');
    ok (! $r->pnotes('request'));

    foreach my $map ({type => 'r', object => $r},
                     {type => 'c', object => $c}) {

        my $type = $map->{type};

        my $o    = $map->{object};

        t_debug("testing $type->pnotes call");
        ok $o->pnotes;

        ok t_cmp($o->pnotes('pnotes_foo', 'pnotes_bar'),
                 'pnotes_bar',
                 "$type->pnotes(key,val)");

        ok t_cmp($o->pnotes('pnotes_foo'),
                 'pnotes_bar',
                 "$type->pnotes(key)");

        ok t_cmp(ref($o->pnotes), 'HASH', "ref($type->pnotes)");

        ok t_cmp($o->pnotes()->{'pnotes_foo'}, 'pnotes_bar',
                 "$type->pnotes()->{}");

        # unset the entry (but the entry remains with undef value)
        $o->pnotes('pnotes_foo', undef);
        ok t_cmp($o->pnotes('pnotes_foo'), undef,
                 "unset $type contents");

        my $exists = exists $o->pnotes->{'pnotes_foo'};
        $exists = 1 if $] < 5.008001; # changed in perl 5.8.1
        ok $exists;

        # now delete completely (possible only via the hash inteface)
        delete $o->pnotes()->{'pnotes_foo'};
        ok t_cmp($o->pnotes('pnotes_foo'), undef,
                 "deleted $type contents");
        ok !exists $o->pnotes->{'pnotes_foo'};

        # test blessed references, like DBI
        # DBD::DBM ships with DBI...
        if (have_module(qw(DBI DBD::DBM))) {
          my $dbh = DBI->connect('dbi:DBM:');

          $o->pnotes(DBH => $dbh);

          my $pdbh = $o->pnotes('DBH');

          ok t_cmp(ref($pdbh), 'DBI::db', "ref($type->pnotes('DBH'))");

          my $quote = $pdbh->quote("quoth'me");

          # see the DBI manpage for why quote() returns the string
          # wrapped in ' marks
          ok t_cmp($quote, "'quoth\\'me'", '$pdbh->quote() works');
        }
        else {
          skip ('skipping $dbh retrival test - no DBI or DBD::DBM');
          skip ('skipping $dbh->quote() test - no DBI or DBD::DBM');
        }
    }

    # set pnotes so we can test unset on later connections
    $r->pnotes(request => 'RSET');
    $c->pnotes(connection => 'CSET');

    ok t_cmp($r->pnotes('request'),
             'RSET',
             '$r->pnotes() set');

    ok t_cmp($c->pnotes('connection'),
             'CSET',
             '$c->pnotes() set');

    Apache2::Const::OK;
}

1;
__END__


