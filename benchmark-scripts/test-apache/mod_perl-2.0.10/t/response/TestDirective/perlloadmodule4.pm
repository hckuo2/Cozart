# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::perlloadmodule4;

# XXX: the package is 99% the same as perlloadlmodule5 and 6, just the
# configuration is different. Consider removing the code dups.
#
# in this test we test an early mod_perl startup caused by an
# EXEC_ON_READ directive in the baseserver. In this test the
# non-native mod_perl directive sets scfg on behalf of mod_perl in
# that vhost.
#
# See also perlloadmodule5.pm, which is almost the same, but uses a
# mod_perl native directive before a non-native directive in vhost. In
# that test mod_perl sets scfg for that vhost by itself.
#
# see perlloadmodule6.pm for the case where mod_perl starts early, but
# from within the vhost.

use strict;
use warnings FATAL => 'all';

use Apache2::CmdParms ();
use Apache2::Module ();
use Apache2::ServerUtil ();

use Apache2::Const -compile => qw(OK);

use constant KEY => "MyTest4";

my @directives = ({ name => +KEY },);

Apache2::Module::add(__PACKAGE__, \@directives);

sub MyTest4 {
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
    PerlLoadModule TestDirective::perlloadmodule4
</Base>
<VirtualHost TestDirective::perlloadmodule4>
    # here perlloadmodule sets scfg on behalf of the base server
    MyTest4 "Vhost"
    <Location /TestDirective__perlloadmodule4>
        MyTest4 "Dir"
        SetHandler modperl
        PerlResponseHandler TestDirective::perlloadmodule4
    </Location>
</VirtualHost>

