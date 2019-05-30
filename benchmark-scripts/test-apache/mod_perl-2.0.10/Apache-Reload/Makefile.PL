use strict;

use lib qw(lib);
use Config;

my %prereqs = ();
my %mp2 = ( mod_perl2 => 1.99022 );
my %mp1 = ( mod_perl  => 0 );
my $at_min_ver = 1.34;

my $mp_gen;
# MOD_PERL_2_BUILD is set from building from mod_perl Makefile.PL which should
# also set MP_APXS
if ($ENV{MOD_PERL_2_BUILD}) {
    push @ARGV, "-apxs", $ENV{MP_APXS};
    my $mp_gen = satisfy_mp_generation(2);
}
else {
    $mp_gen = satisfy_mp_generation();
}

%prereqs = ($mp_gen == 1 ? %mp1 : %mp2);

my $HAS_APACHE_TEST = check_for_apache_test();

my $VERSION;
set_version();

my %common_opts = (
                   VERSION         => $VERSION,
                   PREREQ_PM       => \%prereqs,
                   dist            => {
                       COMPRESS => 'gzip -9f', SUFFIX => 'gz',
                       PREOP   => 'find $(DISTVNAME) -type d -print|xargs chmod 0755 && ' .
                                  'find $(DISTVNAME) -type f -print|xargs chmod 0644',
                       TO_UNIX => 'find $(DISTVNAME) -type f -print|xargs dos2unix'
                   },
                   clean           => { FILES => 't/TEST' },
                  );

### MAINTAINER_BUILDING_RELEASE is hack
### for the Release Manager's use only.
### We will set it so that the resulting
### distribution will be called Apache-Reload-\d+.tar.gz
### and NOT Apache2-Reload-\d+.tar.gz
### This is for historical reasons and consistency
if ($mp_gen == 1 || $ENV{MAINTAINER_BUILDING_RELEASE}) {
    require ExtUtils::MakeMaker;
    ExtUtils::MakeMaker::WriteMakefile(
                                       %common_opts,
                                       NAME            => "Apache::Reload",
                                       ABSTRACT_FROM   => 'lib/Apache/Reload.pm',
                                      );

}
else {
    require ModPerl::MM;
    ModPerl::MM::WriteMakefile(
                               %common_opts,
                               NAME            => "Apache2::Reload",
                               ABSTRACT_FROM   => 'lib/Apache2/Reload.pm',
                              );
}

sub check_for_apache_test {
    return unless eval {
        require Apache::Test;
        if ($Apache::Test::VERSION < $at_min_ver) {
            die "Apache::Test version is " . $Apache::Test::VERSION . 
                ", minimum version required is $at_min_ver" . 
                ", tests will be skipped\n";
        }
        require Apache::TestMM;
        require Apache::TestRunPerl;
        1;
    };

    Apache::TestMM::filter_args();

    my %args = @Apache::TestMM::Argv;

    Apache::TestRunPerl->generate_script();

    return 1;
}

sub set_version {
    require Apache::Reload;
    $VERSION = $Apache::Reload::VERSION;

    my $fh = Symbol::gensym();
    open $fh, 'Changes' or die "Can't open Changes: $!";
    while (<$fh>) {
        if(/^=item.*-(dev|rc\d+)/) {
            $VERSION .= "-$1";
            last;
        }
        last if /^=item/;
    }
    close $fh;
}

# If a specific generation was passed as an argument,
#     if satisfied
#         return the same generation
#     else
#         die
# else @ARGV and %ENV will be checked for specific orders
#     if the specification will be found
#         if satisfied
#             return the specified generation
#         else
#             die
#     else if any mp generation is found
#              return it
#           else
#              die

sub satisfy_mp_generation {
    my $wanted = shift || wanted_mp_generation();

    unless ($wanted == 1 || $wanted == 2) {
        die "don't know anything about mod_perl generation: $wanted\n" .
            "currently supporting only generations 1 and 2";
    }

    my $selected = 0;

    if ($wanted == 1) {
        require_mod_perl();
        if ($mod_perl::VERSION >= 1.99) {
            # so we don't pick 2.0 version if 1.0 is wanted
            die "You don't seem to have mod_perl 1.0 installed";
        }
        $selected = 1;
    }
    elsif ($wanted == 2) {
        #warn "Looking for mod_perl 2.0";
        require_mod_perl();
        if ($mod_perl::VERSION < 2.0) {
            die "You don't seem to have mod_perl 2.0 installed";
        }
        $selected = 2;
    }
    else {
        require_mod_perl();
        $selected = $mod_perl::VERSION >= 1.99 ? 2 : 1;
        warn "Using $mod_perl::VERSION\n";
    }

    return $selected;
}

sub require_mod_perl {
    eval { require mod_perl };
    eval { require mod_perl2 }  if ($@);
    die "Can't find mod_perl installed\nThe error was: $@" if $@;
}

# the function looks at %ENV and Makefile.PL option to figure out
# whether a specific mod_perl generation was requested.
# It uses the following logic:
# via options:
# perl Makefile.PL MOD_PERL=2
# or via %ENV:
# env MOD_PERL=1 perl Makefile.PL
#
# return value is:
# 1 or 2 if the specification was found (mp 1 and mp 2 respectively)
# 0 otherwise
sub wanted_mp_generation {

    # check if we have a command line specification
    # flag: 0: unknown, 1: mp1, 2: mp2
    my $flag = 0;
    foreach my $key (@ARGV) {
        if ($key =~ /^MOD_PERL=(\d)$/) {
            $flag = $1;
        }
    }

    # check %ENV
    my $env = exists $ENV{MOD_PERL} ? $ENV{MOD_PERL} : 0;

    # check for contradicting requirements
    if ($env && $flag && $flag != $env) {
        die <<EOF;
Can\'t decide which mod_perl version should be used, since you have
supplied contradicting requirements:
    enviroment variable MOD_PERL=$env
    Makefile.PL option  MOD_PERL=$flag
EOF
    }

    my $wanted = 0;
    $wanted = 2 if $env == 2 || $flag == 2;
    $wanted = 1 if $env == 1 || $flag == 1;

    unless ($wanted) {
        # if still unknown try to require mod_perl.pm
        eval { require mod_perl };
        if ($@) {
            # if we don't have mp1, check for mp2
            # see if we are in the mp2 build structure
            eval { require File::Spec };
            unless ($@) {
                my $mplib = File::Spec->catdir('..', 'lib');
                unshift @INC, $mplib if -e File::Spec->catfile($mplib,'mod_perl2.pm');
                my $atlib = File::Spec->catdir('../', 'Apache-Test', 'lib');
                unshift @INC, $atlib if -d $atlib;
            } 

            eval { require mod_perl2 } if ($@);
            unless ($@) {
                $wanted = 2;
            }
        }
        else {
            $wanted = 1;
        }
    }

    return $wanted;
}

package MY;

sub postamble {
    my $self = shift;

    my $string = $self->SUPER::postamble;

    $string .= <<'EOF';
tag :
	svn copy https://svn.apache.org/repos/asf/perl/Apache-Reload/trunk https://svn.apache.org/repos/asf/perl/Apache-Reload/tags/$(VERSION_SYM)
	@echo update lib/Apache/Reload.pm VERSION now
EOF

    return $string;
}

sub test {
    my $self = shift;

    eval { require Test::More } or return <<EOF;
test::
\t\@echo sorry, cannot run tests without Test::More
EOF

    return $self->Apache::TestMM::test(@_) if $HAS_APACHE_TEST;

    return <<EOF
test::
\t\@echo
\t\@echo sorry, cannot run tests without a properly
\t\@echo configured Apache-Test environment, mininum
\t\@echo Apache::Test version needed is $at_min_ver
\t\@echo
EOF
}

sub clean {
    my $self = shift;

    return $self->Apache::TestMM::clean(@_) if $HAS_APACHE_TEST;

    return $self->SUPER::clean(@_);
}

sub constants {
    my $self = shift;

    my $string = $self->MM::constants;

    # mp2 installs this into INSTALLSITEARCH, so in order to avoid
    # problems when users forget 'make install UNINST=1', trick MM into
    # installing pure perl modules to the sitearch location, when this is
    # not installed as a part of mp2 build
    if (!$ENV{MOD_PERL_2_BUILD}) {
        $string .= <<'EOI';

# install into the same location as mod_perl 2.0
INSTALLSITELIB = $(INSTALLSITEARCH)
DESTINSTALLSITELIB = $(DESTINSTALLSITEARCH)
EOI
    }

    $string;
}
