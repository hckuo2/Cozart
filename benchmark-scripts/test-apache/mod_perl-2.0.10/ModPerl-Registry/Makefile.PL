use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use FindBin;
use lib grep { -d } map "$FindBin::Bin/../$_", qw(lib Apache-Test/lib);

use ModPerl::BuildMM ();
use Apache::TestSmokePerl ();
use Apache2::Build ();

# enable 'make test|clean'
use Apache::TestMM qw(test clean);

# prerequisites
my %require = (
    "Apache::Test" => "0", # any version will do?
);

my @scripts = qw(t/TEST t/SMOKE);

# accept the configs from comman line
Apache::TestMM::filter_args();

my $build = Apache2::Build->build_config;
if ($build->should_build_apache) {
    push @Apache::TestMM::Argv, ('httpd' => $build->{httpd});
}
Apache::TestMM::generate_script('t/TEST');

# t/SMOKE
Apache::TestSmokePerl->generate_script;

ModPerl::BuildMM::WriteMakefile(
    NAME         => 'ModPerl::Registry',
    VERSION_FROM => 'lib/ModPerl/RegistryCooker.pm',
    PREREQ_PM    => \%require,
    clean        => {
        FILES => "@{ clean_files() }",
    });

sub clean_files {
    return [@scripts, 'Makefile.old'];
}
