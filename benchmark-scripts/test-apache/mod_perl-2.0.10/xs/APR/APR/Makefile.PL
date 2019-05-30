use strict;
use warnings;

use lib qw(../lib);
use ModPerl::BuildMM ();
require ModPerl::Code;
use Apache2::Build ();
use Config;
use File::Spec::Functions;

use constant WIN32   => Apache2::Build::WIN32;
use constant CYGWIN  => Apache2::Build::CYGWIN;
use constant SOLARIS => $^O eq 'solaris';
use constant BUILD_APREXT   => Apache2::Build::BUILD_APREXT;

my %args;

%args = map { split /=/, $_, 2 } @ARGV;

$args{NAME}         = 'APR';
$args{VERSION_FROM} = 'APR.pm';

my $libs = '';
$libs = delete $args{LIBS} if $args{LIBS};

my $build = ModPerl::BuildMM::build_config();

my $ccopts = $build->ccopts;

# avoid referencing &perl_module outside of mod_perl
$ccopts .= ' -DMP_IN_XS';

$args{CCFLAGS} = $ccopts;

my @apru_link_flags = $build->apru_link_flags;
$libs .= join ' ', @apru_link_flags if @apru_link_flags;

if (WIN32) {
    $libs =~ s{/libpath:}{-L}g;
    $libs =~ s{(\S+)\.lib}{-l$1}g;
}

if (BUILD_APREXT) {
    my $mp_apr_lib = $build->mp_apr_lib;

    if (CYGWIN) {
        # For Cygwin compatibility, set $mp_apr_lib before the apache libs
        $libs = qq{ $mp_apr_lib } . $libs;
    } else {
        $libs .= qq{ $mp_apr_lib };
    }
}

if (SOLARIS && $libs) {
    # EU::MM sets LD_RUN_PATH (for linking) based on -L options in LIBS.
    # LD_RUN_PATH is getting overridden by the specified -R path.
    # The -R specified is from the perl config's lddflags.
    # Therefore -R has to be added with the appropriate paths rather
    # than using LD_RUN_PATH, because it gets overridden.

    # make sure that all -L, -R from libs are moved
    # to the beginning of lddflags.
    my $extralddflags = join " ", $libs =~ /(-[LR]\S+)/g;

    # -R makes sure that these paths will be used
    $extralddflags =~ s{-L(\S+)}{-L$1 -R$1}g;
    $args{LDDLFLAGS} = "" unless exists $args{LDDLFLAGS};
    $args{LDDLFLAGS} = join " ", $args{LDDLFLAGS}, $extralddflags,
        $build->perl_config('lddlflags');

    # -R are now copied to LDDFLAGS, but leave -L's in LIBS --
    # EU::MM needs it.
    $libs =~ s{-R\S+}{}g;
}

$args{LIBS} = [$libs] if $libs;

my $srcdir = '../../../src/modules/perl';

# link the following into APR.so so other APR:: modules can be used
# outside of httpd
my @names = ModPerl::Code::src_apr_ext();

my(@obj, @clean, %src);
for (@names) {
    push @obj, join '.', $_, 'o';
    my $cfile = join '.', $_, 'c';
    push @clean, $cfile;
    $src{$cfile} = "$srcdir/$cfile";
}

$args{OBJECT} = BUILD_APREXT() ? "APR.o" : "APR.o @obj";
$args{clean}  = { FILES => "@clean" };

ModPerl::BuildMM::WriteMakefile(%args);

# avoid redefined warnings from imported postamble symbol from
# elsewhere in other Makefile.PL files
no warnings 'redefine';
sub MY::postamble {
    my $self = shift;
    my $string = $self->ModPerl::BuildMM::MY::postamble;

    $string .= join '', map {
        "$_: $src{$_}\n\t\$(CP) $src{$_} .\n";
    } sort keys %src;

    return $string;
}
