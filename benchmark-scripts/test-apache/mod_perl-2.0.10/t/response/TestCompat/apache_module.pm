# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCompat::apache_module;

# Apache2::Module compat layer tests

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache2::compat ();
use Apache::Constants qw(OK);

my @directives = (
    {
        name => 'TestCompatApacheModuleParms',
    },
);

Apache2::Module::add(__PACKAGE__, \@directives);

sub TestCompatApacheModuleParms {
    my ($self, $parms, $args) = @_;
    my $config = Apache2::Module->get_config($self, $parms->server);
    $config->{data} = $args;
}

sub handler : method {
    my ($self, $r) = @_;

    plan $r, tests => 2;

    my $top_module = Apache2::Module->top_module();
    ok t_cmp (ref($top_module), 'Apache2::Module');

    my $config = Apache2::Module->get_config($self, $r->server);
    ok t_cmp ($config->{data}, 'Test');

    OK;
}

1;
__END__

# APACHE_TEST_CONFIG_ORDER 950

<Base>
PerlLoadModule TestCompat::apache_module
</Base>
TestCompatApacheModuleParms "Test"
