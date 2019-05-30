package Apache::TestReload;

use strict;
use warnings FATAL => 'all';

#use ModPerl::Util ();
use Apache::Constants qw(:common);

my $package = 'Reload::Test';

our $pass = 0;

sub handler {
    my $r = shift;
    $pass++;
    $r->send_http_header('text/plain');
    if ((defined ($r->args)) && ($r->args eq 'last')) {
        #Apache2::Reload->unregister_module($package);
        #ModPerl::Util::unload_package($package);
        $pass = 0;
        $r->print("unregistered OK");
        return OK;
    }

    eval "require $package";

    Reload::Test::run($r);

    return OK;
}

# This one shouldn't be touched
package Reload::Test::SubPackage;

sub subpackage {
    if ($Apache::TestReload::pass == '2') {
        return 'SUBPACKAGE';
    }
    else {
        return 'subpackage';
    }
}

1;
