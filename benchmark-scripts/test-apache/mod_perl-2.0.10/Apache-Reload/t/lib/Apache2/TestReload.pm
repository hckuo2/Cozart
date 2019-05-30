package Apache2::TestReload;

use strict;
use warnings FATAL => 'all';

use ModPerl::Util ();
use Apache2::RequestRec ();
use Apache2::Const -compile => qw(OK);
use Apache2::RequestIO ();

my $package = 'Reload::Test';

our $pass = 0;

sub handler {
    my $r = shift;
    $pass++;
    if (defined $r->args and $r->args eq 'last') {
        Apache2::Reload->unregister_module($package);
        ModPerl::Util::unload_package($package);
        $pass = 0;
        $r->print("unregistered OK");
        return Apache2::Const::OK;
    }

    eval "require $package";

    Reload::Test::run($r);

    return Apache2::Const::OK;
}

# This one shouldn't be touched
package Reload::Test::SubPackage;

sub subpackage {
    if ($Apache2::TestReload::pass == '2') {
        return 'SUBPACKAGE';
    }
    else {
        return 'subpackage';
    }
}

1;
