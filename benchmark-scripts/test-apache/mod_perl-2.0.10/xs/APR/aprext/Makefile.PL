use strict;
use warnings;

use lib qw(../lib);
use ModPerl::BuildMM ();
require ModPerl::Code;
use Apache2::Build ();

my $build = ModPerl::BuildMM::build_config();

my $srcdir = '../../../src/modules/perl';
my @names = ModPerl::Code::src_apr_ext();

my(@obj, @clean, %src);
for (@names) {
    push @obj, join '.', $_, 'o';
    my $cfile = join '.', $_, 'c';
    push @clean, $cfile;
    $src{$cfile} = "$srcdir/$cfile";
}

push @obj, q{modperl_dummy.o};

my @skip = qw(dynamic test);
push @skip, q{static}
    unless (Apache2::Build::BUILD_APREXT);

my %args = (NAME          => 'lib' . $build->{MP_APR_LIB},
            VERSION_FROM  => '../APR/APR.pm',
            SKIP          =>  [ @skip ] ,
            LINKTYPE      =>  'static',
            OBJECT        => "@obj",
            clean         => { FILES => "@clean" },
	   );

my $ccopts = $build->ccopts;

# avoid referencing &perl_module outside of mod_perl
$ccopts .= ' -DMP_IN_XS';

$args{CCFLAGS} = $ccopts;

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

    # BSD make needs an empty target, even if the target is specified in .PHONY
    $string .= "\ndynamic ::\n";

    return $string;
}
