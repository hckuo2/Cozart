# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::pnotes2;

use strict;
use warnings FATAL => 'all';

use Apache2::Log ();
use Apache2::RequestUtil ();
use Apache2::ConnectionUtil ();

use Apache2::Const -compile => 'OK';

{
    package TestModerl::pnotes2::x;
    use strict;
    use warnings FATAL => 'all';

    sub new {shift;bless [@_];}
    sub DESTROY {my $f=shift @{$_[0]}; $f->(@{$_[0]});}
}

sub line {
    our $cleanup;

    Apache2::ServerRec::warn "pnotes are destroyed after cleanup ".$cleanup;
}

sub cleanup {
    our $cleanup;
    $cleanup='passed';

    return Apache2::Const::OK;
}

sub handler {
    my $r = shift;

    our $cleanup;
    $cleanup='';

    $r->push_handlers( PerlCleanupHandler=>__PACKAGE__.'::cleanup' );

    if(!defined $r->args) {
    } elsif($r->args == 1) {
        $r->pnotes(x1 => TestModerl::pnotes2::x->new(\&line));
    } elsif($r->args == 2) {
        $r->pnotes->{x1} = TestModerl::pnotes2::x->new(\&line);
    } elsif($r->args == 3) {
        $r->pnotes(x1 => TestModerl::pnotes2::x->new(\&line));
        $r->pnotes(x2 => 2);
    } elsif($r->args == 4) {
        $r->pnotes->{x1} = TestModerl::pnotes2::x->new(\&line);
        $r->pnotes->{x2} = 2;
    } elsif($r->args == 5) {
        $r->pnotes(x1 => TestModerl::pnotes2::x->new(\&line));
        $r->pnotes->{x2} = 2;
    } elsif($r->args == 6) {
        $r->pnotes->{x1} = TestModerl::pnotes2::x->new(\&line);
        $r->pnotes(x2 => 2);
    } elsif($r->args == 7) {
        $r->connection->pnotes(x1 => TestModerl::pnotes2::x->new(\&line));
    } elsif($r->args == 8) {
        $r->connection->pnotes->{x1} = TestModerl::pnotes2::x->new(\&line);
    } elsif($r->args == 9) {
        $r->connection->pnotes(x1 => TestModerl::pnotes2::x->new(\&line));
        $r->connection->pnotes(x2 => 2);
    } elsif($r->args == 10) {
        $r->connection->pnotes->{x1} = TestModerl::pnotes2::x->new(\&line);
        $r->connection->pnotes->{x2} = 2;
    } elsif($r->args == 11) {
        $r->connection->pnotes(x1 => TestModerl::pnotes2::x->new(\&line));
        $r->connection->pnotes->{x2} = 2;
    } elsif($r->args == 12) {
        $r->connection->pnotes->{x1} = TestModerl::pnotes2::x->new(\&line);
        $r->connection->pnotes(x2 => 2);
    }

    $r->content_type('text/plain');
    $r->print("OK");

    Apache2::Const::OK;
}

1;
__END__
