# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use warnings;
use strict;

use Apache::Test ();
use Apache::TestUtil;
use File::Spec::Functions qw(catfile catdir);

use lib catdir Apache::Test::vars('serverroot'), 'cgi-bin';
my $require = catfile Apache::Test::vars('serverroot'),
    qw(cgi-bin perlrun_nondecl.pl);

print "Content-type: text/plain\n\n";

### declared package module ###
{
    # require a module w/ package declaration (it doesn't get reloaded
    # because it declares the package). But we still have a problem with
    # subs declaring prototypes. When perlrun_decl->import is called, the
    # original function's prototype doesn't match the aliases prototype.
    # see decl_proto()
    BEGIN { t_server_log_warn_is_expected()
                if perlrun_decl->can("decl_proto");
    }
    use perlrun_decl;

    die "perlrun_decl BEGIN block was run more than once"
        if $MyData::blocks{perlrun_decl} > 1;

    print "d";
    print decl_proto(1);
}

### non-declared package module ###
{
    # how many times were were called from the same interpreter
    $MyData::blocks{cycle}{perlrun_nondecl}++;
    $MyData::blocks{BEGIN}{perlrun_nondecl} ||= 0;
    $MyData::blocks{END}  {perlrun_nondecl} ||= 0;

    # require a lib w/o package declaration. Functions in that lib get
    # automatically aliased to the functions in the current package.
    require "$require";

    die "perlrun_nondecl's BEGIN block wasn't run"
        if $MyData::blocks{BEGIN}{perlrun_nondecl} !=
           $MyData::blocks{cycle}{perlrun_nondecl};

    # the END block for this cycle didn't run yet, but we can test the
    # previous cycle's one
    die "perlrun_nondecl's END block wasn't run"
        if $MyData::blocks{END}{perlrun_nondecl} + 1 !=
           $MyData::blocks{cycle}{perlrun_nondecl};

    # they all get redefined warning inside perlrun_nondecl.pl, since that
    # lib loads it into main::, vs. PerlRun undefs the current __PACKAGE__
    print "nd";
    print nondecl_no_proto();
    print nondecl_proto(2);
    print nondecl_proto_empty("whatever");
    print nondecl_const();
}
