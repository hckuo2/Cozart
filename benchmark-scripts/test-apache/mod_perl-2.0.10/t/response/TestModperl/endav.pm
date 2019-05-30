# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::endav;

use strict;
use warnings FATAL => 'all';

use ModPerl::Global ();

use Apache::Test;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 4;

    #just to make sure we dont segv with bogus values
    my $not = 'NoSuchPackage';
    for my $name ('END', $not) {
        ModPerl::Global::special_list_call( $name => $not);
        ModPerl::Global::special_list_clear($name => $not);
    }

    # register the current package to set its END blocks aside
    ModPerl::Global::special_list_register(END => __PACKAGE__);
    # clear anything that was previously set
    ModPerl::Global::special_list_clear(END => __PACKAGE__);
    eval 'END { ok 1 }';

    # now run them twice:ok 1 (1), ok 1 (2)
    ModPerl::Global::special_list_call(END => __PACKAGE__);
    ModPerl::Global::special_list_call(END => __PACKAGE__);

    ModPerl::Global::special_list_clear(END => __PACKAGE__);
    #should do nothing
    ModPerl::Global::special_list_call( END => __PACKAGE__);

    # this we've already registered this package's END blocks, adding
    # new ones will set them aside
    eval 'END { ok 1 }';

    # so this will run ok 1 (3)
    ModPerl::Global::special_list_call( END => __PACKAGE__);
    ModPerl::Global::special_list_clear(END => __PACKAGE__);

    ModPerl::Global::special_list_clear(END => __PACKAGE__);
    #should do nothing
    ModPerl::Global::special_list_call( END => __PACKAGE__);

    # one plain ok 1 (4)
    ok 1;

    Apache2::Const::OK;
}

1;
__END__
SetHandler perl-script
