# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
TestModperl::setupenv2::register_mixed();
TestModperl::setupenv2::register_perl();
$ENV{EnvChangeMixedTest} = "require";
$ENV{EnvChangePerlTest}  = "require";
1;
