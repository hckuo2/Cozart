# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::perlloadmodule7;

# this test was written to reproduce a segfault under worker
# due to a bug in custom directive implementation, where
# the code called from modperl_module_config_merge() was setting the
# global context after selecting the new interpreter which was leading
# to a segfault in any handler called thereafter, whose context was
# different beforehand.

use strict;
use warnings FATAL => 'all';

use Apache2::Module ();

use Apache2::Const -compile => qw(OK);

use constant KEY1 => "MyTest7_1";
use constant KEY2 => "MyTest7_2";

my @directives = ({ name => +KEY1 }, { name => +KEY2 });

Apache2::Module::add(__PACKAGE__, \@directives);

sub MyTest7_1 {
    my ($self, $parms, $arg) = @_;
    $self->{+KEY1} = $arg;
}

sub MyTest7_2 {
    my ($self, $parms, $arg) = @_;
    $self->{+KEY2} = $arg;
}

### response handler ###

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);

sub handler {
    my ($r) = @_;

    plan $r, tests => 1;

    ok 1;

    return Apache2::Const::OK;
}

1;
__END__

<NoAutoConfig>
# APACHE_TEST_CONFIG_ORDER 950
PerlLoadModule TestDirective::perlloadmodule7

MyTest7_1 test
<Location /TestDirective__perlloadmodule7>
    MyTest7_2 test
    SetHandler modperl
    PerlResponseHandler TestDirective::perlloadmodule7
</Location>
</NoAutoConfig>
