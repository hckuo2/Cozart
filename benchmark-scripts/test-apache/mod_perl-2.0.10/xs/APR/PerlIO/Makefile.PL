use lib qw(../lib);
use ModPerl::BuildMM ();

use Config;
use Apache2::Build;
use Apache::TestTrace;
my $build = Apache2::Build->build_config();

my $ccopts = $build->ccopts;

# when uselargefiles is on, -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64
# are needed to get the right 'Off_t', without which perlio compiled
# with Off_t as 'long long int', doesn't quite work with apr_perlio.c
# compiled with Off_t as 'long int'
#
# On the other handl if apr is built without large files support, we
# have binary compatibility problems, if we try to build mod_perl with
# -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64
#
# XXX: it seems that enabling these flags only for apr_perlio/PerlIO
# seems to do the trick
if ($build->has_large_files_conflict) {
    $ccopts .= $Config{uselargefiles}
        ? ' ' . $Config{ccflags_uselargefiles}
        : '';
}

# avoid referencing &perl_module outside of mod_perl
$ccopts .= ' -DMP_IN_XS';

ModPerl::BuildMM::WriteMakefile(
    NAME         => 'APR::PerlIO',
    VERSION_FROM => 'PerlIO.pm',
    CCFLAGS      => $ccopts,
    OBJECT       => 'PerlIO.o modperl_apr_perlio.o'
);

