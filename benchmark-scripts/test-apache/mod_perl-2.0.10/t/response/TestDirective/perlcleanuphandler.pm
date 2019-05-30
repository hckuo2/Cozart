# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::perlcleanuphandler;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Connection ();
use Apache2::ConnectionUtil ();
use Apache2::Const -compile => 'OK', 'DECLINED';

# This test is to show an error that occurs if in the whole request cycle
# only a PerlCleanupHandler is defined. In this case it is not called.
# To check that "/get?incr" is called first. This returns "UNDEF" to the
# browser and sets the counter to "1". Next "/get" is called again without
# args to check the counter without increment. Then we fetch
# "/index.html?incr". Here no other Perl*Handler save the PerlCleanupHandler
# is involved. So the next "/get" must return "2" but it shows "1".

sub cleanup {
    my $r=shift;
    $r->connection->pnotes->{counter}++ if( $r->args eq 'incr' );
    return Apache2::Const::OK;
}

sub get {
    my $r=shift;
    $r->content_type('text/plain');
    $r->print($r->connection->pnotes->{counter} || "UNDEF");
    return Apache2::Const::OK;
}

1;

__END__
<VirtualHost TestDirective::perlcleanuphandler>

    <IfDefine PERL_USEITHREADS>
        # a new interpreter pool
        PerlOptions +Parent
        PerlInterpStart         1
        PerlInterpMax           1
        PerlInterpMinSpare      0
        PerlInterpMaxSpare      1
        # PerlInterpScope         connection
    </IfDefine>

    KeepAlive On
    KeepAliveTimeout 300
    MaxKeepAliveRequests 100

    # use test system's @INC
    PerlSwitches -I@serverroot@
    PerlRequire "conf/modperl_inc.pl"
    PerlModule TestDirective::perlcleanuphandler

    <Location /get>
        SetHandler modperl
        PerlResponseHandler TestDirective::perlcleanuphandler::get
    </Location>

    PerlCleanupHandler TestDirective::perlcleanuphandler::cleanup

</VirtualHost>
