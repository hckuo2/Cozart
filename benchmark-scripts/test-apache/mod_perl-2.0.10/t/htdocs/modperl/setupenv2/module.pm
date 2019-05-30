# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package htdocs::modperl::setupenv2::module;
TestModperl::setupenv2::register_mixed();
TestModperl::setupenv2::register_perl();
$ENV{EnvChangeMixedTest} = "perlmodule";
$ENV{EnvChangePerlTest}  = "perlmodule";
1;
