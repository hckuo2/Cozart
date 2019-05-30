# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::module;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestConfig;
use Apache::TestUtil;
use Apache2::BuildConfig;

use Apache2::Module ();
use DynaLoader ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $cfg = Apache::Test::config();

    my $top_module = Apache2::Module::top_module();

    my $module_count = 0;
    for (my $modp = $top_module; $modp; $modp = $modp->next) {
        $module_count++;
    }

    my $tests = 12 + ( 5 * $module_count );

    plan $r, tests => $tests;

    my $core = Apache2::Module::find_linked_module('core.c');
    ok defined $core && $core->name eq 'core.c';

    #.c
    ok t_cmp Apache2::Module::loaded('mod_perl.c'), 1,
        "Apache2::Module::loaded('mod_perl.c')";

    ok t_cmp Apache2::Module::loaded('Apache__Module_foo.c'), 0,
        "Apache2::Module::loaded('Apache__Module_foo.c')";

    #.so
    {
        my $build = Apache2::BuildConfig->new;
        my $expect = $build->should_build_apache ? 0 : 1;
        ok t_cmp Apache2::Module::loaded('mod_perl.so'), $expect,
            "Apache2::Module::loaded('mod_perl.so')";
    }

    ok t_cmp Apache2::Module::loaded('Apache__Module__foo.so'), 0,
        "Apache2::Module::loaded('Apache__Module_foo.so')";

    #perl
    {
        ok t_cmp Apache2::Module::loaded('Apache2::Module'), 1,
            "Apache2::Module::loaded('Apache2::Module')";

        ok t_cmp Apache2::Module::loaded('Apache__Module_foo'), 0,
            "Apache2::Module::loaded('Apache__Module_foo')";

        # TestAPI::module::foo wasn't loaded but the stash exists
        $TestAPI::module::foo::test = 1;
        ok t_cmp Apache2::Module::loaded('TestAPI::module::foo'), 0,
            "Apache2::Module::loaded('TestAPI::module::foo')";

        # module TestAPI wasn't loaded but the stash exists, since
        # TestAPI::module was loaded
        ok t_cmp Apache2::Module::loaded('TestAPI'), 0,
            "Apache2::Module::loaded('TestAPI')";
    }

    #bogus
    ok t_cmp Apache2::Module::loaded('Apache__Module_foo.foo'), 0,
        "Apache2::Module::loaded('Apache__Module_foo.foo')";

    ok t_cmp Apache2::Module::loaded(''), 0,
        "Apache2::Module::loaded('')";

    ok t_cmp ref($top_module), 'Apache2::Module', 'top_module';

    my $mmn_major = $cfg->{httpd_info}{MODULE_MAGIC_NUMBER_MAJOR};
    my $mmn_minor = $cfg->{httpd_info}{MODULE_MAGIC_NUMBER_MINOR};
    for (my $modp = $top_module; $modp; $modp = $modp->next) {
        my $name = $modp->name;
        ok $name;
        t_debug("Testing module: " . $modp->name);
        ok t_cmp $modp->ap_api_major_version, $mmn_major;
        ok $modp->ap_api_minor_version <= $mmn_minor;
        ok $modp->module_index >= 0;
        my $cmds = $modp->cmds;
        ok !defined($cmds) || ref($cmds) eq 'Apache2::Command';
    }

    Apache2::Const::OK;
}

1;
