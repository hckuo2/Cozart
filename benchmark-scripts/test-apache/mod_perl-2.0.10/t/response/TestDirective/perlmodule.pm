# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::perlmodule;

# This test is similar to TestDirective::perlrequire. Here we test
# whether vhost inheriting the parent perl from the base can handle
# PerlModule directives.

use strict;
use warnings FATAL => 'all';

use Apache::Test ();

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use File::Spec::Functions qw(catfile);

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    $r->puts($ApacheTest::PerlModuleTest::MAGIC || '');

    Apache2::Const::OK;
}

sub APACHE_TEST_CONFIGURE {
    my ($class, $self) = @_;

    my $vars = $self->{vars};
    my $target_dir = catfile $vars->{documentroot}, 'testdirective';

    my $magic = __PACKAGE__;
    my $content = <<EOF;
package ApacheTest::PerlModuleTest;
\$ApacheTest::PerlModuleTest::MAGIC = '$magic';
1;
EOF
    my $file = catfile $target_dir,
        'perlmodule-vh', 'ApacheTest', 'PerlModuleTest.pm';
    $self->writefile($file, $content, 1);
}

1;
__END__

# APACHE_TEST_CONFIG_ORDER 940

<Base>
    PerlSwitches -I@documentroot@/testdirective/perlmodule-vh
</Base>

<VirtualHost TestDirective::perlmodule>
    PerlModule ApacheTest::PerlModuleTest

    <Location /TestDirective__perlmodule>
        SetHandler modperl
        PerlResponseHandler TestDirective::perlmodule
    </Location>

</VirtualHost>
