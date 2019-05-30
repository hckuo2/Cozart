# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::internal_redirect;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();

use Apache::TestTrace;

use Apache2::Const -compile => 'OK';

sub modperl {
    my $r = shift;

    my %args = map { split('=', $_, 2) } split /[&]/, $r->args;
    if ($args{main}) {
        # sub-req
        $r->content_type('text/plain');
        debug "modperl: sub-req: response";
        $r->print("internal redirect: $args{main} => modperl");
    }
    else {
        # main-req
        my $redirect_uri = $args{uri};
        debug "modperl: main-req => $redirect_uri?main=modperl";
        $r->internal_redirect("$redirect_uri?main=modperl");
    }

    Apache2::Const::OK;
}

sub perl_script {
    my $r = shift;

    my %args = map { split('=', $_, 2) } split /[&]/, $r->args;
    if ($args{main}) {
        # sub-req
        $r->content_type('text/plain');
        debug "perl-script: sub-req: response";
        print "internal redirect: $args{main} => perl-script";
    }
    else {
        # main-req
        my $redirect_uri = $args{uri};
        debug "perl-script: main-req => $redirect_uri?main=perl-script";
        $r->internal_redirect("$redirect_uri?main=perl-script");
    }

    Apache2::Const::OK;
}
1;
__DATA__
<NoAutoConfig>
    PerlModule TestAPI::internal_redirect
    <Location /TestAPI__internal_redirect_modperl>
        SetHandler modperl
        PerlResponseHandler TestAPI::internal_redirect::modperl
    </Location>
    <Location /TestAPI__internal_redirect_perl_script>
        SetHandler perl-script
        PerlResponseHandler TestAPI::internal_redirect::perl_script
    </Location>
</NoAutoConfig>
