# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package ModPerl::RegistryPrefork;

use strict;
use warnings FATAL => 'all';

our $VERSION = '0.01';

use base qw(ModPerl::Registry);

if ($ENV{MOD_PERL}) {
    require Apache2::MPM;
    die "This package can't be used under threaded MPMs"
        if Apache2::MPM->is_threaded;
}

sub handler : method {
    my $class = (@_ >= 2) ? shift : __PACKAGE__;
    my $r = shift;
    return $class->new($r)->default_handler();
}

*chdir_file = \&ModPerl::RegistryCooker::chdir_file_normal;

1;
__END__
