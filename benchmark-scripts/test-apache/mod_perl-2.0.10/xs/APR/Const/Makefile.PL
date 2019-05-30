use lib qw(../lib);
use ModPerl::BuildMM ();
use Apache2::Build;

my $build = Apache2::Build->build_config();
my $ccopts = $build->ccopts;

# avoid referencing &perl_module outside of mod_perl
$ccopts .= ' -DMP_IN_XS';

ModPerl::BuildMM::WriteMakefile(
    NAME => 'APR::Const',
    VERSION_FROM => 'Const.pm',
    CCFLAGS      => $ccopts,
);
