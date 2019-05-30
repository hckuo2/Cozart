use lib qw(../lib);
use ModPerl::BuildMM ();

my $srcdir = '../../../src/modules/perl';
#link these two into Const.so so constants can be used outside of httpd
my @names = map { "modperl_$_" } qw(const constants);
my(@obj, @clean, %src);

for (@names) {
    push @obj, join '.', $_, 'o';
    my $cfile = join '.', $_, 'c';
    push @clean, $cfile;
    $src{$cfile} = "$srcdir/$cfile";
}

ModPerl::BuildMM::WriteMakefile(
    NAME => 'ModPerl::Const',
    VERSION_FROM => 'Const.pm',
    OBJECT => "Const.o @obj",
    clean => { FILES => "@clean" },
);

sub MY::postamble {
    my $self = shift;
    my $string = $self->ModPerl::BuildMM::MY::postamble;

    $string .= join '', map {
        "$_: $src{$_}\n\t\$(CP) $src{$_} .\n";
    } sort keys %src;

    return $string;
}
