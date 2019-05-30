# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::setupenv2;

# Test the mixing of PerlSetEnv in httpd.conf and %ENV of the same
# key in PerlRequire, PerlConfigRequire, PerlPostConfigRequire and
# <Perl> sections

use strict;
use warnings FATAL => 'all';

use Apache2::Const -compile => qw(OK OR_ALL NO_ARGS);

use Apache2::CmdParms ();
use Apache2::Module ();
use Apache2::RequestIO ();
use Apache2::RequestRec ();

my @directives = (
    {
     name         => 'MyEnvRegister',
     func         => __PACKAGE__ . '::MyEnvRegister',
     req_override => Apache2::Const::OR_ALL,
     args_how     => Apache2::Const::NO_ARGS,
     errmsg       => 'cannot fail :)',
    },
);

Apache2::Module::add(__PACKAGE__, \@directives);

# testing PerlLoadModule
$ENV{EnvChangeMixedTest} = 'loadmodule';
$ENV{EnvChangePerlTest}  = 'loadmodule';

sub MyEnvRegister {
    register_mixed();
}

sub register_mixed {
    push @TestModperl::setupenv2::EnvChangeMixedTest,
        $ENV{EnvChangeMixedTest} || 'notset';
}

sub register_perl {
    push @TestModperl::setupenv2::EnvChangePerlTest,
        $ENV{EnvChangePerlTest}  || 'notset';
}

sub get_config {
    my ($self, $s) = (shift, shift);
    Apache2::Module::get_config($self, $s, @_);
}

sub handler {
    my ($r) = @_;

    my $args = $r->args || '';

    $r->content_type('text/plain');

    if ($args eq 'mixed') {
        my @vals = (@TestModperl::setupenv2::EnvChangeMixedTest,
            $ENV{EnvChangeMixedTest}); # what's the latest env value
        $r->print(join " ", @vals);
    }
    elsif ($args eq 'perl') {
        my @vals = (@TestModperl::setupenv2::EnvChangePerlTest,
            $ENV{EnvChangePerlTest}); # what's the latest env value
        $r->print(join " ", @vals);
    }
    else {
        die "no such case";
    }

    return Apache2::Const::OK;
}

1;
__END__

# APACHE_TEST_CONFIG_ORDER 950

<NoAutoConfig>
PerlLoadModule TestModperl::setupenv2
MyEnvRegister

PerlSetEnv EnvChangeMixedTest "conf1"

<Perl >
TestModperl::setupenv2::register_mixed();
TestModperl::setupenv2::register_perl();
$ENV{EnvChangeMixedTest} = "<perl>";
$ENV{EnvChangePerlTest}  = "<perl>";
</Perl>
MyEnvRegister

PerlSetEnv EnvChangeMixedTest "conf2"

PerlRequire           "@documentroot@/modperl/setupenv2/require.pl"
MyEnvRegister

PerlSetEnv EnvChangeMixedTest "conf3"

PerlConfigRequire     "@documentroot@/modperl/setupenv2/config_require.pl"
MyEnvRegister

PerlSetEnv EnvChangeMixedTest "conf4"

PerlModule htdocs::modperl::setupenv2::module
MyEnvRegister

PerlSetEnv EnvChangeMixedTest "conf5"
MyEnvRegister

PerlPostConfigRequire "@documentroot@/modperl/setupenv2/post_config_require.pl"
MyEnvRegister

PerlSetEnv EnvChangeMixedTest "conf6"
MyEnvRegister

PerlSetEnv EnvChangeMixedTest "conf7"
MyEnvRegister

<Location /TestModperl__setupenv2>
    SetHandler modperl
    PerlResponseHandler TestModperl::setupenv2
</Location>

PerlSetEnv EnvChangeMixedTest "conf8"

# Since PerlPostConfigRequire runs in the post-config phase it will
# see 'conf8'. And when it sets that value to 'post_config_require' at
# request time $ENV{EnvChangeMixedTest} will see the value set by
# PerlPostConfigRequire.

</NoAutoConfig>
