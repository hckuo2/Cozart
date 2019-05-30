# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
TestModperl::setupenv2::register_mixed();
TestModperl::setupenv2::register_perl();
$ENV{EnvChangeMixedTest} = "post_config_require";
$ENV{EnvChangePerlTest}  = "post_config_require";
1;
