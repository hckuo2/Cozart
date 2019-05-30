# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::perlrequire;

# Test whether vhost with 'PerlOptions +Parent', which doesn't inherit
# from the base, has its own INC and therefore can have a modules with
# the same namespace as the base, but different content.
#
# Also see the parallel TestDirective::perlmodule handler

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
    $r->puts($ApacheTest::PerlRequireTest::MAGIC || '');

    Apache2::Const::OK;
}

my %require_tests =
    (
     main => 'PerlRequired by Parent',
     vh   => 'PerlRequired by VirtualHost',
    );

sub APACHE_TEST_CONFIGURE {
    my ($class, $self) = @_;

    my $vars = $self->{vars};
    my $target_dir = catfile $vars->{documentroot}, 'testdirective';

    # create two different PerlRequireTest.pm packages to be loaded by
    # vh and main interpreters, on the fly before the tests start
    while (my ($test, $magic) = each %require_tests) {
        my $content = <<EOF;
package ApacheTest::PerlRequireTest;
\$ApacheTest::PerlRequireTest::MAGIC = '$magic';
1;
EOF
        my $file = catfile $target_dir,
            $test, 'ApacheTest', 'PerlRequireTest.pm';
        $self->writefile($file, $content, 1);
    }
}

1;
__END__
# APACHE_TEST_CONFIG_ORDER 940

<Base>
    PerlSwitches -I@documentroot@/testdirective/main
    PerlRequire "ApacheTest/PerlRequireTest.pm"
</Base>

<VirtualHost TestDirective::perlrequire>

    <IfDefine PERL_USEITHREADS>
        # a new interpreter pool
        PerlOptions +Parent
        PerlInterpStart         1
        PerlInterpMax           1
        PerlInterpMinSpare      1
        PerlInterpMaxSpare      1
    </IfDefine>

    # use test system's @INC
    PerlSwitches -I@serverroot@
    PerlRequire "conf/modperl_inc.pl"

    PerlSwitches -I@documentroot@/testdirective/vh
    PerlRequire "ApacheTest/PerlRequireTest.pm"

    <Location /TestDirective__perlrequire>
        SetHandler modperl
        PerlResponseHandler TestDirective::perlrequire
    </Location>

</VirtualHost>
