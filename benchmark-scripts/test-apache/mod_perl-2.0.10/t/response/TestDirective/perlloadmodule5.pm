# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::perlloadmodule5;

# in this test we test an early mod_perl startup caused by an
# EXEC_ON_READ directive in the baseserver. In this test we have a
# mod_perl native directive before a non-native directive inside vhost
# section. Here mod_perl sets scfg for that vhost by itself.
#
# See also perlloadmodule4.pm, which is almost the same, but has no
# mod_perl native directive before a non-native directive in vhost. In
# that test the non-native mod_perl directive sets scfg on behalf of
# mod_perl in that vhost.
#
# see perlloadmodule6.pm for the case where mod_perl starts early, but
# from within the vhost.

use strict;
use warnings FATAL => 'all';

use Apache2::CmdParms ();
use Apache2::Module ();
use Apache2::ServerUtil ();

use Apache2::Const -compile => qw(OK);

use constant KEY => "MyTest5";

my @directives = ({ name => +KEY },);

Apache2::Module::add(__PACKAGE__, \@directives);

sub MyTest5 {
    my ($self, $parms, $arg) = @_;
    $self->{+KEY} = $arg;
    unless ($parms->path) {
        my $srv_cfg = Apache2::Module::get_config($self, $parms->server);
        $srv_cfg->{+KEY} = $arg;
    }
}

### response handler ###

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::Module ();
use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);

sub get_config {
    Apache2::Module::get_config(__PACKAGE__, @_);
}

sub handler {
    my ($r) = @_;
    my %secs = ();

    $r->content_type('text/plain');

    my $s = $r->server;
    my $dir_cfg = get_config($s, $r->per_dir_config);
    my $srv_cfg = get_config($s);

    plan $r, tests => 3;

    ok $s->is_virtual;

    ok t_cmp($dir_cfg->{+KEY}, "Dir", "Section");

    ok t_cmp($srv_cfg->{+KEY}, "Vhost", "Section");

    return Apache2::Const::OK;
}


1;
__END__

# APACHE_TEST_CONFIG_ORDER 950

<Base>
    PerlLoadModule TestDirective::perlloadmodule5
</Base>
<VirtualHost TestDirective::perlloadmodule5>
    # here mod_perl sets the scfg by itself for this vhost
    PerlModule File::Spec
    MyTest5 "Vhost"
    <Location /TestDirective__perlloadmodule5>
        MyTest5 "Dir"
        SetHandler modperl
        PerlResponseHandler TestDirective::perlloadmodule5
    </Location>
</VirtualHost>
