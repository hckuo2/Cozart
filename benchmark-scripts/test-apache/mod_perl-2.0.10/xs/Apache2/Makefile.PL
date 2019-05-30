use lib qw(../lib);
use ModPerl::BuildMM ();

ModPerl::BuildMM::WriteMakefile(
    NAME => "Apache2_build",
    VERSION => '0.01'
);
