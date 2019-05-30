use lib qw(../lib);
use ModPerl::BuildMM ();

ModPerl::BuildMM::WriteMakefile(
    NAME => 'Apache2::Const',
    VERSION_FROM => 'Const.pm',
);
