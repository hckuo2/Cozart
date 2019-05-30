use 5.006;
use strict;
use warnings FATAL => 'all';

# useful for sub-Makefile.PL's to know whether they are invoked
# directly or via the top level Makefile.PL
$ENV{MOD_PERL_2_BUILD} = 1;

use constant MIN_HTTPD_VERSION_DYNAMIC => '2.0.47';
use constant MIN_HTTPD_VERSION_STATIC  => '2.0.51';
use constant MIN_HTTPD_24_VERSION => '2.4.0';

my($old_modperl_version, $old_modperl_pm, $old_Apache2_pm);

BEGIN {
    eval {
        my $old_mp2 = eval { require Apache2 };
        require mod_perl;
        if ($mod_perl::VERSION < 1.999_22 && $old_mp2) {
            $old_modperl_version = $mod_perl::VERSION;
            $old_modperl_pm = delete $INC{'mod_perl.pm'};
            $old_Apache2_pm = delete $INC{'Apache2.pm'};
        }
    };

}

use lib qw(lib Apache-Test/lib);

use Config;
use File::Spec::Functions;
use File::Spec;
use DirHandle ();
use File::Copy 'cp';
use File::Basename qw(basename dirname);
use File::Find ();

use Apache2::Build ();
use Apache::TestSmokePerl ();
use Apache::TestTrace;
use ModPerl::TestReport ();
use ModPerl::TestRun ();
use ModPerl::Code ();
use ModPerl::BuildMM ();

use constant WIN32 => Apache2::Build::WIN32;
use constant BUILD_APREXT => Apache2::Build::BUILD_APREXT;

our $VERSION;

my $build = Apache2::Build->new(init => 1);
my $code  = ModPerl::Code->new;

sub UNATTENDED() { $build->{MP_PROMPT_DEFAULT} || ! -t STDIN }

# may populate $build->{MP_APXS}
win32_fetch_apxs() if WIN32;

configure();
perl_version_check($build);

local %ModPerl::BuildMM::PM = (
    'lib/typemap' => 'blib/lib/Apache2/typemap',
);

# these h files need to be installed system-wide so 3rd party XS
# extensions can use them
my @xs_h_files = map catfile("xs", $_),
    qw(modperl_xs_sv_convert.h modperl_xs_typedefs.h modperl_xs_util.h
       APR/PerlIO/modperl_apr_perlio.h);
my @exe_files =  map "bin/$_", qw(mp2bug);

ModPerl::BuildMM::WriteMakefile(
    NAME          => 'mod_perl2',
    VERSION       => $VERSION,
    DISTNAME      => 'mod_perl',
    NO_META       => 1,
    ABSTRACT_FROM => 'lib/mod_perl2.pm',
    EXE_FILES     => \@exe_files,
    DEFINE        => get_DEFINE(),
    macro         => {
        MODPERL_SRC           => $code->path,
        MODPERL_MAKEFILE      => basename($build->default_file('makefile')),
        PERL                  => $build->perl_config('perlpath'),
        MOD_INSTALL           => ModPerl::BuildMM::mod_install(),
        MODPERL_AP_INCLUDEDIR =>
            $build->ap_destdir($build->install_headers_dir),
        MODPERL_XS_H_FILES    => join(" \\\n\t", @xs_h_files),
    },
    clean     => {
        FILES => "@{ clean_files() }",
    },
    dist      => {
        DIST_DEFAULT => 'mydist',
        COMPRESS     => 'gzip -9f', SUFFIX=>'gz',
        PREOP        => 'find $(DISTVNAME) -type d -print|xargs chmod 0755 && ' .
                        'find $(DISTVNAME) -type f -print|xargs chmod 0644',
        TO_UNIX      => 'find $(DISTVNAME) -type f -print|xargs dos2unix'
    },
);

post_configure();

sub get_DEFINE {

    my $opt_define = '';

    # do we have apr libs?
    # XXX: this define is really needed in xs/APR/APR/Makefile.PL, but this 
    # top-level Makefile.PL overrides MY::pasthru, and defines DEFINE= which
    # overrides any local definition, not sure what's the right fix, for
    # now just define it here (should it define PASTHRU_DEFINE instead?)
    $opt_define = '-DMP_HAVE_APR_LIBS' if $build->apru_link_flags;

    # preserve any DEFINE opts from outside and combine them with our
    # local DEFINE
    @ARGV = grep defined,
        map { (/^DEFINE=(.*)/ && ($opt_define .= " $1")) ? undef : $_ } @ARGV;

    return $opt_define;
}

sub configure {

    # mod_perl test suite relies on having Apache-Test bundled with
    # the mod_perl source, since any pre-installed version may not do
    # the right thing
    unless (-d "Apache-Test") {
        error "Can't find a sub-directory Apache-Test. " .
            "Make sure that you are using a complete source distribution";
        exit 1;
    }

    set_modperl_version();

    if ($old_modperl_version) {
        (my $old_modperl_version_str = $old_modperl_version)
            =~ s/(\d\d\d?)(\d\d)/$1_$2/;
        my $vstring = "mod_perl/$old_modperl_version_str";
        print "$vstring installation detected...";

        my $prefix;
        /^PREFIX=(.*)/ && $1 && ($prefix = canonpath glob($1)) for @ARGV;

        # check that it's a full path
        my $path = canonpath $old_modperl_pm;
        # XXX: doesn't handle relative paths yet
        # if PREFIX=/foo/bar is used, and it's not the same as the
        # path where mod_perl < 1.999_22 is installed
        if ($prefix && $path !~ /^$prefix/) {
            print "ok (will install mod_perl/$VERSION into PREFIX=$prefix, " .
                "no collision)\n";
        }
        else {
            my $note = '';
            if ($old_Apache2_pm) {
                $note .= "Conflicting file: $old_Apache2_pm\n";
            }
            if ($path =~ /Apache2/ or $old_modperl_version > 1.99) {
                my $dir = dirname $path;
                # was it installed into the top-level?
                $dir = catdir $dir, 'Apache' unless $path =~ /Apache2/;
                $note .= "Conflicting dir: $dir\n" if -d $dir;
            }

            print " not ok\n\n";
            print <<EOI;
Cannot install mod_perl/$VERSION on top of $vstring
due to a major API change between mod_perl 1.999_21 and 1.999_22.

$note
Please nuke the prior mod_perl installation from your site_lib,
use a different perl to run the installation process, or use the
PREFIX option when creating your Makefile.  See:

  http://perl.apache.org/docs/2.0/rename.html

for more details.

aborting...
EOI
                    exit 1;
        }
    }
    else {
        print "no conflicting prior mod_perl version found - good.\n";

    }

    # On Win32, in order to decouple APR::* from mod_perl.so, we
    # make up a static library MP_APR_LIB of the symbols required from
    # src/modules/perl/*.c (see xs/APR/aprext/Makefile.PL), and
    # then link APR/APR::* against this library. The reason for
    # this is that, unlike Unix, if we had linked APR/APR::* against
    # the mod_perl lib, then use of APR/APR::* would demand mod_perl.so
    # be available, even if these symbols are supplied by another
    # loaded library (which is done for unix by APR.so - see
    # xs/APR/APR/Makefile.PL). This also means we must ensure the
    # MP_APR_LIB lib is built before any of the APR/APR::* modules 
    # (see the aprext target in the MY::top_targets sub below), as 
    # symbols must get resolved at link time.

    if (BUILD_APREXT()) {
        require File::Path;
        #Makefile.PL's in WrapXS/ just need to pass the -e mod_perl.lib test
        #the real mod_perl.lib will be in place when WrapXS/ dll's are
        #actually linked
        # this must also be done for aprext.lib, build in xs/APR/aprext/;
        # we must create a dummy aprext.lib to pass the -e test.
        my $lib1 = catfile qw(src modules perl), 
            $build->{MP_LIBNAME} . $Config{lib_ext};
        my ($apr_blib, $full_libname) = $build->mp_apr_blib();
        my $lib2 = catfile $apr_blib, $full_libname;
        unless (-d $apr_blib) {
            File::Path::mkpath($apr_blib) or die "mkdir $apr_blib failed: $!";
        }
        foreach my $lib ($lib1, $lib2) {
            unless (-e $lib) {
                open my $fh, '>', $lib or die "open $lib: $!";
                print $fh "#this is a dummy file to trick MakeMaker";
                close $fh;
            }
        }
    }

    system_sanity_check();

    my $min_httpd_version = $build->should_build_apache
        ? MIN_HTTPD_VERSION_STATIC
        : MIN_HTTPD_VERSION_DYNAMIC;

    if ($build->{MP_APXS}) {
        print "Using APXS => $build->{MP_APXS}\n";
    }
    elsif ($build->{MP_AP_PREFIX}) {
        if (my $reason = $build->ap_prefix_invalid) {
            error "invalid MP_AP_PREFIX: $reason";
            exit 1;
        }
        print "Using Apache prefix => $build->{MP_AP_PREFIX}\n";
    }
    else {
        unless ($build->{MP_USE_STATIC}) {
            # may populate $build->{MP_APXS}
            prompt_for_apxs($build);
        }
    }

    $build->{$_} and $ENV{$_} = $build->{$_} for (qw/MP_APXS MP_AP_PREFIX/);

    unless ($build->{MP_APXS} or $build->{MP_AP_PREFIX}) {
        my $ok = 0;
        for my $path ($build->find) {
            $build->dir($path);
            my $mmn = $build->module_magic_number;
            my $v   = $build->httpd_version;
            next unless $v;
            next if $v lt $min_httpd_version;
            $ok++ if $build->prompt_y("Configure mod_perl with $path?");
            last if $ok;
        }
        until ($ok) {
            my $ask = "Please provide the location of the Apache directory:";
            my $ans = $build->prompt($ask) || "";
            # strip leading/closing spaces
            $ans =~ s/^\s*|\s*$//g;
            if (defined $ans and -d $ans) {
                $build->dir($ans);
                $ok++;
            }
            else {
                error "Can't find dir '$ans'";
                last if UNATTENDED;
            }
        }
    }

    if ($build->should_build_apache) {
        $build->configure_apache();
    }

    my $httpd_version = $build->httpd_version;
    unless ($httpd_version) {
        error 'Unable to determine server version, aborting.';
        if ($build->{MP_APXS} || $build->{MP_AP_PREFIX}) {
            my $what = $build->{MP_APXS} ? 'MP_APXS' : 'MP_AP_PREFIX';
            error "Invalid $what specified?";
        }
        else {
            error 'Please specify MP_APXS or MP_AP_PREFIX.';
        }
        exit(1);
    }

    if ($httpd_version lt $min_httpd_version) {
        error "Apache/$httpd_version not supported, " .
              "$min_httpd_version or higher is required";
        exit(1);
    }

    printf "Configuring Apache/%s mod_perl/%s Perl/v%vd\n",
        $httpd_version, $VERSION, $^V;

    my $apr_config = $build->get_apr_config; #cache it

    # we need to know where apr-config and apu-configs are
    # which sometimes aren't placed into the same dir with apxs/httpd
    # XXX: need to fix that for WIN32
    # XXX: when the source tree is used, there is not much use for apr-config
    unless (WIN32 || $build->apr_config_path || $build->httpd_is_source_tree) {
        error "can't find 'apr-config', please pass " .
            "MP_APR_CONFIG=/full/path/to/apr-config to 'perl Makefile.PL'";
        exit 1;
    }

    for (@{ clean_files() }) {
        debug "unlink...$_" if -e $_ && unlink;
    }

    #ModPerl::BuildMM will use Apache2::BuildConfig in subdir/Makefile.PL's
    $build->save;

    ModPerl::TestRun->generate_script;
    ModPerl::TestReport->generate_script;
    Apache::TestSmokePerl->generate_script;

    my $tables_dir = tables_dir($httpd_version);

    unshift @INC, $tables_dir;

    if ($build->{MP_GENERATE_XS}) {
        debug "generating XS code using $tables_dir...";
        xs_generate($httpd_version);
    }

    install_typemap();
}

sub prompt_for_apxs {
    my $build = shift;

    print <<EOI;

Next we need to know where the 'apxs' script is located. This script
provides a lot of information about the Apache installation, and makes
it easier to find things on your system. Normally it's located in the
same directory as the 'httpd' executable.

If you don't yet have Apache installed you can build Apache against
the Apache source code, but you won't be able to run the test suite (a
very important step). Therefore you may want to install Apache before
proceeding.

EOI

    my $prompt = "\nPlease provide a full path to 'apxs' executable\n" .
        "(press Enter if you don't have it installed):";
    while (1) {
        my $ans = $build->prompt($prompt) || "";

        print "\n\n";

        # strip leading/closing spaces
        $ans =~ s/^\s*|\s*$//g;

        last unless length $ans; # skip

        unless (File::Spec->file_name_is_absolute($ans)) {
            warn "The path '$ans' is not an absolute path. " .
                "Please specify an absolute path.\n";
            next;
        }

        warn("'$ans' doesn't exist.\n"),     next unless -e $ans;
        warn("'$ans' is not a file.\n"),     next unless -f _;
        warn("'$ans' is not executable.\n"), next unless -x _;

        $build->{MP_APXS} = $ans;
        last;
    }
}

sub post_configure {

    #now have any data subdir/Makefile.PL's save, e.g. XS
    $build = Apache2::Build->build_config;

    $build->write_src_makefile;
    $build->save_ldopts;

    $code->generate($build);

    for my $type (qw(DSO STATIC)) {
        next unless $build->{"MP_USE_$type"};
        warning "mod_perl \L$type\E library will be built as ".
          $build->{"MODPERL_LIB_$type"};
    }

    if ($build->is_dynamic) {
        warning
            "You'll need to add the following to httpd.conf:",            "",
            "  LoadModule perl_module modules/$build->{MODPERL_LIB_DSO}", "",
            "depending on your build, mod_perl might not live in",
            "the modules/ directory.\n";
        if ($build->{MP_APXS}) {
            warning 
                "Check the results of",                                   "",
                "  \$ $build->{MP_APXS} -q LIBEXECDIR",                   "",
                "and adjust the LoadModule directive accordingly.\n";
        }
    }

    $build->save;
}

sub tables_dir {
    my $httpd_version = shift;

    my $tables_version='';
    if ($httpd_version lt MIN_HTTPD_24_VERSION) {
        $tables_version='current';
    }
    else {
        $tables_version='current24';
    }

    my $tables_dir = "xs/tables/$tables_version";
}

sub xs_generate {
    require ModPerl::WrapXS;

    my $xs = ModPerl::WrapXS->new;

    $xs->generate;

    #shift @INC; #ModPerl::Code needs this path too
}

sub install_typemap {
    my $to_file = 'lib/typemap';

    open my $to_fh, ">$to_file" or die "open $to_file: $!";

    for my $from_file (qw(WrapXS/typemap xs/typemap)) {
        open my $from_fh, $from_file or die "open $from_file: $!";
        cp $from_fh, $to_fh;
        close $from_fh;
    }

    close $to_fh or die "close $to_file: $!";
}

sub echo_cmd {
    my $cmd = shift;
    print "$cmd\n";
    system($cmd) == 0 or exit(1);
}

sub clean_files {
    my $path = $code->path;

    my @files = ();
    File::Find::find(sub { push @files, "$File::Find::dir/$_" if -f $_},
                     "WrapXS") if -d "WrapXS";

    push @files, map { "xs/$_.h" }
        qw(modperl_xs_typedefs modperl_xs_sv_convert);

    return [@{ $build->clean_files },
            @files,
            qw(lib/typemap
               lib/ModPerl/MethodLookup.pm
               lib/ModPerl/DummyVersions.pm
               t/htdocs/vhost/error_log
               t/SMOKE
               t/TEST
               t/REPORT
              ),
            <t/htdocs/hooks/startup/open_logs*>,
            <t/htdocs/hooks/startup/post_config*>,
            <xs/*.exp>,
            <xs/*.def>,
            map { "$path/$_"} @{ $code->clean_files }
           ];
}

sub set_modperl_version {
    require './lib/mod_perl2.pm';

    $VERSION = $mod_perl2::VERSION_TRIPLET;

    open my $fh, 'Changes';
    while (<$fh>) {
        if (/^=item\s+\Q$VERSION\E-(dev|rc\d+)/) {
            $VERSION .= "-$1";
            last;
        }
        last if /^=item/;
    }
    close $fh;

    $build->{VERSION}     = $VERSION;
    $build->{API_VERSION} = $mod_perl2::API_VERSION;
}

# needs to be run after configure() when apxs is setup
sub perl_version_check {
    my $build = shift;

    my $perl_version = $];
    $perl_version =~ s/5.00(\d)(?:00(\d))?/"5.$1." . ($2||0)/e;
    my $perl_threads = Apache2::Build::PERL_HAS_ITHREADS ? "w/" : "w/o";
    my $perl_string = "Using Perl $perl_version $perl_threads ithreads";
    my $httpd_version = $build->httpd_version;
    my $mpm = "";
    my $build_threaded = 0;

    # For httpd-2.4, we can't use mpm_is_threaded(), because MPMs are loadable
    # modules. We therefore treat httpd as a whole project as threaded. It is
    # still possible to disable threading by using MP_NO_THREADS=1
    if ($httpd_version lt MIN_HTTPD_24_VERSION) {
        $build_threaded = $build->mpm_is_threaded();
        $mpm = $build->mpm_name();
    }
    else {
        if ($build->{MP_NO_THREADS}) {
            $build_threaded = 0;
        }
        else {
            $build_threaded = 1;
        }
    }

    # certain mpms require perl 5.8.0+ w/ithreads
    if ($build_threaded) {
        my @fail;
        push @fail, "Perl 5.8 or higher"
            unless $] >= 5.008;
        push @fail, "Perl built with ithreads (build perl with -Duseithreads)"
            unless Apache2::Build::PERL_HAS_ITHREADS();
        if (@fail) {
            if ($httpd_version lt MIN_HTTPD_24_VERSION) {
                error "$perl_string and '$mpm' mpm httpd.",
                    "Failed requirements:",
                    join "", map {"  - $_\n"} @fail;
            }
            else {
                error "$perl_string and httpd-2.4.",
                    "Failed requirements:",
                    join "", map {"  - $_\n"} @fail;
            }
            exit 1;
        }
    }
    else {
        # before 5.8.2, perl_shutdown is incomplete (in the case of ithreads 
        # each PerlInterpreter * gets tossed so it works)
        if ($build->should_build_apache && !Apache2::Build::PERL_HAS_ITHREADS) {
            # before 5.8.2, perl_shutdown is incomplete
            if ($] < 5.008_002) {
                if ($httpd_version lt MIN_HTTPD_24_VERSION) {
                    error "static $mpm mpm requires a threaded ".
                        "perl 5.6.1-5.8.1 or any perl 5.8.2+";
                }
                else {
                    error "httpd-2.4 requires a threaded ".
                        "perl 5.6.1-5.8.1 or any perl 5.8.2+";
                }
                exit 1;
            }
        }
    }

    if ($] < 5.006_001) {
        error "$perl_string. You need at least Perl 5.6.1";
        exit 1;
    }

    if ($] >= 5.007 and $] < 5.008) {
        error "$perl_string.",
            "5.7.x development versions of Perl are no longer supported",
            "Upgrade to Perl 5.8.0 or higher";
        exit 1;
    }

    if ($Config{usemultiplicity} xor $Config{useithreads}) {
        error "mod_perl does not currently support multiplicity without ".
	      "ithreads.";
        if ($build_threaded) {
	    error "Please recompile Perl with -Duseithreads and ".
	          "-Dusemultiplicity";
        } else {
	    error "Please recompile Perl with either -Duseithreads and ".
	          "-Dusemultiplicity or -Uuseithreads and -Uusemultiplicity";
	}
        exit 1;
    }
}

sub system_sanity_check {
    return if WIN32;

    my $ccflags = $build->perl_config('ccflags');
    for (split /\s+/, $ccflags) {
        next unless s/^-I//;
        my $header = "$_/ap_mmn.h";
        if (-e $header) {
            $build->phat_warn(<<EOF);
Apache headers found in unexpected location: ``$_'', suggestions:
   *) Remove via ``rpm -e apache''
   *) Remove by hand
   *) Complain to your os vendor about their poor layout choice
   *) Complain to your sysadmin about their poor layout choice
EOF
        }
    }

    $build->lib_check('gdbm');
    malloc_check();
    os_check();
}

sub malloc_check {
    return unless $build->is_dynamic;
    return unless $build->perl_config('usemymalloc') eq 'y';

    my $abort = $^O eq 'solaris';

    my $bincompat = $build->perl_config('bincompat5005');

    if ($bincompat) {
             $build->phat_warn(<<EOF, $abort);
Your current configuration will most likely trigger core dumps, suggestions:
   *) Do not configure mod_perl as a DSO
   *) Rebuild Perl without malloc pollution (Configure -Ubincompat5005)
EOF
    }
}

sub os_check {
    my $check = \&{"os_check_$^O"};
    return unless defined &$check;
    $check->()
}

sub os_check_hpux {
    my $ccflags = $build->perl_config('ccflags');
    my $ld = $build->perl_config('ld');

    if ($build->is_dynamic and $ld eq 'ld') {
        unless ($ccflags =~ /\+z/i) {
            $build->phat_warn(<<EOF);
mod_perl is unlikely to link with your libperl, suggestions:
    *) Rebuild Perl with Configure -Accflags=+Z ...
EOF
        }
    }
}

sub win32_fetch_apxs {
    return unless (my $prefix = $build->{MP_AP_PREFIX});
    my $script = catfile($build->{cwd}, 'build', 'win32_fetch_apxs');
    my @args = ($^X, $script, "--with-apache2=$prefix");
    system(@args) == 0 or die "system @args failed: $?";
    my $apxs = catfile($prefix, 'bin', 'apxs.bat');
    $build->{MP_APXS} = $apxs if -e $apxs;
}


package MY;

use Config;
use constant WIN32 => $^O eq 'MSWin32';
use constant BUILD_APREXT => Apache2::Build::BUILD_APREXT;

sub MY::top_targets {
    my $self = shift;
    my $string = $self->ModPerl::BuildMM::MY::top_targets;

    if (BUILD_APREXT) {
        ModPerl::MM::add_dep(\$string, pure_all => 'aprext');

        # must not import File::Spec functions inside MY, it breaks
        # 5.6.x builds
        my ($apr_blib, $full_libname) = $build->mp_apr_blib();
        my $from = File::Spec->catfile($apr_blib, $full_libname);
        (my $ap_lib = $build->ap_includedir()) =~ s{include$}{lib};
        my $to = File::Spec->catfile($ap_lib, $full_libname);
        my $src_dir = File::Spec->catdir(qw(xs APR), 'aprext');
        $string .= <<"EOF";

aprext:
	cd "$src_dir" && \$(MAKE) all \$(PASTHRU) LINKTYPE="static"

aprext_install:
	\@\$(MKPATH) "$ap_lib"
	\$(CP) "$from" "$to"

EOF
    }

    if ($build->should_build_apache) {
        ModPerl::MM::add_dep(\$string, pure_all => 'ap_build');
        $string .= <<"EOF";
ap_build: modperl_lib
	cd "$build->{MP_AP_PREFIX}" && make

ap_install: ap_build
	cd "$build->{MP_AP_PREFIX}" && make DESTDIR=\$(DESTDIR) install
EOF
    }

    ModPerl::MM::add_dep(\$string, pure_all => 'modperl_lib');

    $string .= <<'EOF';

source_scan:
	$(PERL) build/source_scan.pl

xs_generate:
	$(PERL) build/xs_generate.pl

bugreport:
	$(PERL) bin/mp2bug

etags:
	$(SHELL) build/make_etags

modperl_lib:
	cd "$(MODPERL_SRC)" && $(MAKE)

modperl_lib_install:
	cd "$(MODPERL_SRC)" && $(MAKE) DESTDIR=$(DESTDIR) install

modperl_xs_h_install:
	@$(MKPATH) $(DESTDIR)$(MODPERL_AP_INCLUDEDIR)
	$(CP) $(MODPERL_XS_H_FILES) $(DESTDIR)$(MODPERL_AP_INCLUDEDIR)

modperl_src_clean:
	cd "$(MODPERL_SRC)" && $(MAKE) clean

EOF

    # $(ECHO) was broken before 6.10_01
    # XXX: if ever require 6.11 we can remove this workaround
    require ExtUtils::MakeMaker;
    (my $mm_ver = ExtUtils::MakeMaker->VERSION) =~ s/_\d+//;
    my $say = $mm_ver > 6.10
        ? '@$(ECHO)'
        : '@$(PERL) -le "print shift"';

    $string .= <<"EOF";
modperl_banner:
	$say "+--------------------------------------------------------------+"
	$say "|                                                              |"
	$say "| For details on getting started with mod_perl 2, see:         |"
	$say "|                                                              |"
	$say "|   http://perl.apache.org/docs/2.0/user/intro/start_fast.html |"
	$say "|                                                              |"
	$say "|                                                              |"
	$say "| Found a bug?  File a bug report:                             |"
	$say "|                                                              |"
	$say "|   http://perl.apache.org/bugs/                               |"
	$say "|                                                              |"
	$say "+--------------------------------------------------------------+"

EOF

    $string;
}

sub MY::install {
    my $self = shift;
    my $string = $self->MM::install(@_);

    for my $kind ('', '_site', '_vendor') {
        ModPerl::MM::add_dep(\$string, "pure${kind}_install" => 'ap_install')
	    if $build->should_build_apache;
	ModPerl::MM::add_dep(\$string, "pure${kind}_install" => 'modperl_lib_install');
	ModPerl::MM::add_dep(\$string, "pure${kind}_install" => 'modperl_xs_h_install');
	# ModPerl::MM::add_dep(\$string, "pure${kind}_install" => 'aprext_install')
	#    if BUILD_APREXT;

	ModPerl::MM::add_dep_after(\$string, "install$kind", "doc${kind}_install", 'modperl_banner');

	# glue_pods target must come first
	ModPerl::MM::add_dep(\$string, "pure${kind}_install" => 'glue_pods');
    }

    $string;
}

sub MY::clean {
    my $self = shift;
    my $string = $self->MM::clean(@_);
    ModPerl::MM::add_dep(\$string, clean => 'modperl_src_clean');
    ModPerl::MM::add_dep(\$string, clean => 'test_clean');
    $string;
}

sub MY::test {

    my $preamble;
    if (Apache::TestConfig::WIN32) {
        # need to add the location of Apache's dlls to the PATH
        my $ap_bindir = $build->apr_bindir() || '';
        unless ($ap_bindir) {
            $ap_bindir = File::Spec->catdir($build->{MP_AP_PREFIX}, 'bin')
                if $build->{MP_AP_PREFIX};
        }
        my $modperl_libexecdir = '';
        if ($build->is_dynamic) {
            # need to add the location of mod_perl.so to the PATH
            my $lib = $build->modperl_libpath() || '';
            if ($lib) {
                $modperl_libexecdir = File::Basename::dirname($lib);
            }
            else {
                $modperl_libexecdir = File::Spec->catdir($build->{cwd},
                                                         'src/modules/perl')
                    if $build->{cwd};
            }
        }
        my $extra_path = '';
        $extra_path .= ";$ap_bindir" if $ap_bindir;
        $extra_path .= ";$modperl_libexecdir" if $modperl_libexecdir;
        $preamble = <<EOF;
PATH = \$(PATH)$extra_path
EOF
    }
    else {
        # PASSENV confuses the Win32 command-line build
        my $env = Apache::TestConfig->passenv_makestr();
        $preamble = <<EOF;
PASSENV = $env
EOF
    }

    $preamble .= <<'EOF';
TEST_VERBOSE = 0
TEST_FILES =

test_clean :
	$(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	t/TEST -clean

run_tests : test_clean
	$(PASSENV) \
	$(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	t/TEST -bugreport -verbose=$(TEST_VERBOSE) $(TEST_FILES)

run_subtests ::
	cd ModPerl-Registry && $(MAKE) test

run_subtests ::
	cd Apache-Reload && $(MAKE) test

EOF

    $preamble .= <<'EOF' unless $build->mpm_is_threaded();
run_subtests ::
	cd Apache-SizeLimit && $(MAKE) test

EOF

    $preamble .= <<'EOF';
test :: pure_all run_tests run_subtests
EOF

    return $preamble;
}

sub MY::postamble {
    my $self = shift;

    my $string = $self->ModPerl::BuildMM::MY::postamble;

    if (!WIN32) {
        $string .= <<'EOF';
rpm: dist
	@[ -d $(PWD)/rpm ] || mkdir $(PWD)/rpm
	rpmbuild -ta --define "_rpmdir $(PWD)/rpm" \
                 --define "_srcrpmdir $(PWD)/rpm" \
                 $(DISTVNAME).tar.gz
	@mv $(PWD)/rpm/*/*.rpm $(PWD)/rpm/
	@rm -rf $(PWD)/rpm/*/
    
EOF
    }

    my $q = (WIN32 ? '"' : "'");

    $string .= <<"EOF";
mydist : Apache-Test/META.yml mod_perl.spec manifest tardist

mod_perl.spec: build/make_rpm_spec
	\$(PERL) build/make_rpm_spec

Apache-Test/META.yml:
	cd Apache-Test && make metafile

tag :
	svn copy -m $q\$(VERSION_SYM) release branch$q https://svn.apache.org/repos/asf/perl/modperl/trunk  https://svn.apache.org/repos/asf/perl/modperl/branches/release/\$(VERSION_SYM)
	svn copy -m $q\$(VERSION_SYM) tag$q https://svn.apache.org/repos/asf/perl/modperl/branches/release/\$(VERSION_SYM)  https://svn.apache.org/repos/asf/perl/modperl/tags/\$(VERSION_SYM)
	svn copy -m $q\$(VERSION_SYM) tag$q https://svn.apache.org/repos/asf/perl/modperl/docs/trunk https://svn.apache.org/repos/asf/perl/modperl/docs/tags/\$(VERSION_SYM)
EOF

    return $string;
}

# this is a workaround so that ModPerl::MM will move MY::constants
# away, and Apache-Test/Makefile.PL which has its own MY::constants
# won't get complaints on MY::constants redefined
sub MY::constants {
    shift->ModPerl::BuildMM::MY::constants;
}

sub MY::tool_autosplit {
    '';
}

sub MY::manifypods {
    my $self = shift;
    my $ver = $self->{VERSION} || "";
    local $_ = $self->MM::manifypods(@_);
    s/pod2man\s*$/pod2man --release mod_perl-$ver/m;
    $_;
}

sub MY::pasthru {
    my $self = shift;
    chomp(my $str = $self->MM::pasthru);
    join $/, "$str\\",
    "\t".'PERL="$(PERL)"\\',
    "\t".'DEFINE="$(DEFINE)"',
    "";
}

sub MY::dist_basics {
    my $self = shift;
    my $str = $self->MM::dist_basics;

    $str =~ s/(\"?)-MExtUtils(::Manifest=mkmanifest)/-Ilib $1-MModPerl$2/;

    $str;
}
