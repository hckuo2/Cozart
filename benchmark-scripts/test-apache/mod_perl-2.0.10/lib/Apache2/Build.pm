# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package Apache2::Build;

use 5.006;
use strict;
use warnings;

use Config;
use Cwd ();
use File::Spec::Functions qw(catfile catdir canonpath rel2abs devnull
                             catpath splitpath);
use File::Basename;
use ExtUtils::Embed ();
use File::Copy ();

BEGIN {				# check for a sane ExtUtils::Embed
    unless ($ENV{MP_USE_MY_EXTUTILS_EMBED}) {
	my ($version, $path)=(ExtUtils::Embed->VERSION,
			      $INC{q{ExtUtils/Embed.pm}});
	my $msg=<<"EOF";
I have found ExtUtils::Embed $version at

  $path

This is probably not the right one for this perl version. Please make sure
there is only one version of this module installed and that it is the one
that comes with this perl version.

If you insist on using the ExtUtils::Embed as is set the environment
variable MP_USE_MY_EXTUTILS_EMBED=1 and try again.

EOF
	if (eval {require Module::CoreList}) {
	    my $req=$Module::CoreList::version{$]}->{q/ExtUtils::Embed/};
	    die "Please repair your Module::CoreList" unless $req;
	    unless ($version eq $req) {
		$msg.=("Details: expecting ExtUtils::Embed $req ".
		       "(according to Module::CoreList)\n\n");
		die $msg;
	    }
	}
	else {
	    my $req=$Config{privlib}.'/ExtUtils/Embed.pm';
	    unless ($path eq $req) {
		$msg.="Details: expecting ExtUtils::Embed at $req\n\n";
		die $msg;
	    }
	}
    }
}

use constant IS_MOD_PERL_BUILD => grep 
    { -e "$_/Makefile.PL" && -e "$_/lib/mod_perl2.pm" } qw(. ..);

use constant AIX     => $^O eq 'aix';
use constant DARWIN  => $^O eq 'darwin';
use constant CYGWIN  => $^O eq 'cygwin';
use constant IRIX    => $^O eq 'irix';
use constant HPUX    => $^O eq 'hpux';
use constant OPENBSD => $^O eq 'openbsd';
use constant WIN32   => $^O eq 'MSWin32';

use constant MSVC => WIN32() && ($Config{cc} eq 'cl');
use constant DMAKE => WIN32() && ($Config{make} eq 'dmake');

use constant REQUIRE_ITHREADS => grep { $^O eq $_ } qw(MSWin32);
use constant PERL_HAS_ITHREADS =>
    $Config{useithreads} && ($Config{useithreads} eq 'define');
use constant BUILD_APREXT => WIN32() || CYGWIN();

use ModPerl::Code ();
use ModPerl::BuildOptions ();
use Apache::TestTrace;
use Apache::TestConfig ();

our $VERSION = '0.01';
our $AUTOLOAD;

sub AUTOLOAD {
    my $self = shift;
    my $name = uc ((split '::', $AUTOLOAD)[-1]);
    unless ($name =~ /^MP_/) {
        die "no such method: $AUTOLOAD";
    }
    unless ($self->{$name}) {
        return wantarray ? () : undef;
    }
    return wantarray ? (split /\s+/, $self->{$name}) : $self->{$name};
}

#--- apxs stuff ---

our $APXS;

my %apxs_query = (
    INCLUDEDIR => 'include',
    LIBEXECDIR => 'modules',
    CFLAGS     => undef,
    PREFIX     => '',
);

sub ap_prefix_invalid {
    my $self = shift;

    my $prefix = $self->{MP_AP_PREFIX};

    unless (-d $prefix) {
        return "$prefix: No such file or directory";
    }

    my $include_dir = $self->apxs(-q => 'INCLUDEDIR');

    unless (-d $include_dir) {
        return "include/ directory not found in $prefix";
    }

    return '';
}

sub httpd_is_source_tree {
    my $self = shift;

    return $self->{httpd_is_source_tree}
        if exists $self->{httpd_is_source_tree};

    my $prefix = $self->dir;
    $self->{httpd_is_source_tree} = 
        defined $prefix && -d $prefix && -e "$prefix/CHANGES";
}

# try to find the apxs utility, set $self->{MP_APXS} to the path if found,
# otherwise to ''
sub find_apxs_util {
    my $self = shift;

    if (not defined $self->{MP_APXS}) {
        $self->{MP_APXS} = ''; # not found
    }

    my @trys = ($Apache2::Build::APXS,
                $self->{MP_APXS},
                $ENV{MP_APXS});

    push @trys, catfile $self->{MP_AP_PREFIX}, 'bin', 'apxs' 
        if exists $self->{MP_AP_PREFIX};

    if (WIN32) {
        my $ext = '.bat';
        for (@trys) {
            $_ .= $ext if ($_ and $_ !~ /$ext$/);
        }
    }

    unless (IS_MOD_PERL_BUILD) {
        #if we are building mod_perl via apxs, apxs should already be known
        #these extra tries are for things built outside of mod_perl
        #e.g. libapreq
        # XXX: this may pick a wrong apxs version!
        push @trys,
        Apache::TestConfig::which('apxs'),
        '/usr/local/apache/bin/apxs';
    }

    my $apxs_try;
    for (@trys) {
        next unless ($apxs_try = $_);
        chomp $apxs_try;
        if (-x $apxs_try) {
            $self->{MP_APXS} = $apxs_try;
            last;
        }
    }
}

# if MP_AP_DESTDIR was specified this sub will prepend this path to
# any Apache-specific installation path (that option is used only by
# package maintainers).
sub ap_destdir {
    my $self = shift;
    my $path = shift || '';
    return $path unless $self->{MP_AP_DESTDIR};

    if (WIN32) {
        my ($dest_vol, $dest_dir) = splitpath $self->{MP_AP_DESTDIR}, 1;
        my $real_dir = (splitpath $path)[1];

        $path = catpath $dest_vol, catdir($dest_dir, $real_dir), '';
    }
    else {
        $path = catdir $self->{MP_AP_DESTDIR}, $path;
    }

    return canonpath $path;
}

sub apxs {
    my $self = shift;

    $self->find_apxs_util() unless defined $self->{MP_APXS};

    my $is_query = (@_ == 2) && ($_[0] eq '-q');

    $self = $self->build_config unless ref $self;

    my $query_key;
    if ($is_query) {
        $query_key = 'APXS_' . uc $_[1];
        if (exists $self->{$query_key}) {
            return $self->{$query_key};
        }
    }

    unless ($self->{MP_APXS}) {
        my $prefix = $self->{MP_AP_PREFIX} || "";
        return '' unless -d $prefix and $is_query;
        my $val = $apxs_query{$_[1]};
        return defined $val ? ($val ? "$prefix/$val" : $prefix) : "";
    }

    my $devnull = devnull();
    my $val = qx($self->{MP_APXS} @_ 2>$devnull);
    chomp $val if defined $val;

    unless ($val) {
        # do we have an error or is it just an empty value?
        my $error = qx($self->{MP_APXS} @_ 2>&1);
        chomp $error if defined $error;
        if ($error) {
            error "'$self->{MP_APXS} @_' failed:";
            error $error;
        }
        else {
            $val = '';
        }
    }

    $self->{$query_key} = $val;
}

sub apxs_cflags {
    my $who = caller_package(shift);
    my $cflags = $who->apxs('-q' => 'CFLAGS');
    $cflags =~ s/\"/\\\"/g;
    $cflags;
}

sub apxs_extra_cflags {
    my $who = caller_package(shift);
    my $flags = $who->apxs('-q' => 'EXTRA_CFLAGS');
    $flags =~ s/\"/\\\"/g;
    $flags;
}

sub apxs_extra_cppflags {
    my $who = caller_package(shift);
    my $flags = $who->apxs('-q' => 'EXTRA_CPPFLAGS') ." ".
        $who->apxs('-q' => 'NOTEST_CPPFLAGS');
    $flags =~ s/\"/\\\"/g;
    $flags;
}

sub caller_package {
    my $arg = shift;
    return ($arg and ref($arg) eq __PACKAGE__) ? $arg : __PACKAGE__;
}

my %threaded_mpms = map { $_ => 1 }
        qw(worker winnt beos mpmt_os2 netware leader perchild threadpool
           dynamic);
sub mpm_is_threaded {
    my $self = shift;
    my $mpm_name = $self->mpm_name();
    return exists $threaded_mpms{$mpm_name} ? 1 : 0;
}

sub mpm_name {
    my $self = shift;

    return $self->{mpm_name} if $self->{mpm_name};

    if ($self->httpd_version =~ /^(\d+)\.(\d+)\.(\d+)/) {
	delete $threaded_mpms{dynamic} if $self->mp_nonthreaded_ok;
	return $self->{mpm_name} = 'dynamic' if ($1*1000+$2)*1000+$3>=2003000;
    }

    # XXX: hopefully apxs will work on win32 one day
    return $self->{mpm_name} = 'winnt' if WIN32;

    my $mpm_name;

    # httpd >= 2.3
    if ($self->httpd_version_as_int =~ m/^2[3-9]\d+/) {
        $mpm_name = 'dynamic';
    }
    else {
        $mpm_name = $self->apxs('-q' => 'MPM_NAME');
    }

    # building against the httpd source dir
    unless (($mpm_name and $self->httpd_is_source_tree)) {
        if ($self->dir) {
            my $config_vars_file = catfile $self->dir,
                "build", "config_vars.mk";
            if (open my $fh, $config_vars_file) {
                while (<$fh>) {
                    if (/MPM_NAME = (\w+)/) {
                        $mpm_name = $1;
                        last;
                    }
                }
                close $fh;
            }
        }
    }

    unless ($mpm_name) {
        my $msg = 'Failed to obtain the MPM name.';
        $msg .= " Please specify MP_APXS=/full/path/to/apxs to solve " .
            "this problem." unless exists $self->{MP_APXS};
        error $msg;
        die "\n";
    }

    return $self->{mpm_name} = $mpm_name;
}

sub should_build_apache {
    my ($self) = @_;
    return $self->{MP_USE_STATIC} ? 1 : 0;
}

sub configure_apache {
    my ($self) = @_;

    unless ($self->{MP_AP_CONFIGURE}) {
        error "You specified MP_USE_STATIC but did not specify the " .
              "arguments to httpd's ./configure with MP_AP_CONFIGURE";
        exit 1;
    }

    unless ($self->{MP_AP_PREFIX}) {
        error "You specified MP_USE_STATIC but did not speficy the " .
              "location of httpd's source tree with MP_AP_PREFIX"; 
        exit 1;
    }

    debug "Configuring httpd in $self->{MP_AP_PREFIX}";

    my $httpd = File::Spec->catfile($self->{MP_AP_PREFIX}, 'httpd');
    $self->{'httpd'} ||= $httpd;
    push @Apache::TestMM::Argv, ('httpd' => $self->{'httpd'});

    my $mplibpath = '';
    my $ldopts = $self->ldopts;

    if (CYGWIN) {
        # Cygwin's httpd port links its modules into httpd2core.dll,
        # instead of httpd.exe. In this case, we have a problem,
        # because libtool doesn't want to include static libs (.a)
        # into a dynamic lib (.dll). Workaround this by setting
        # mod_perl.a as a linker argument (including all other flags
        # and libs).
        my $mplib  = "$self->{MP_LIBNAME}$Config{lib_ext}";

        $ldopts = join ' ',
            '--export-all-symbols',
            '--enable-auto-image-base',
            "$self->{cwd}/src/modules/perl/$mplib",
            $ldopts;

        $ldopts =~ s/(\S+)/-Wl,$1/g;

    } else {
        my $mplib  = "$self->{MP_LIBNAME}$Config{lib_ext}";
        $mplibpath = catfile($self->{cwd}, qw(src modules perl), $mplib);
    }

    local $ENV{BUILTIN_LIBS} = $mplibpath;
    local $ENV{AP_LIBS} = $ldopts;
    local $ENV{MODLIST} = 'perl';

    # XXX: -Wall and/or -Werror at httpd configure time breaks things
    local $ENV{CFLAGS} = join ' ', grep { ! /\-Wall|\-Werror/ } 
        split /\s+/, $ENV{CFLAGS} || '';

    my $cd = qq(cd $self->{MP_AP_PREFIX});

    # We need to clean the httpd tree before configuring it
    if (-f File::Spec->catfile($self->{MP_AP_PREFIX}, 'Makefile')) {
        my $cmd = qq(make clean);
        debug "Running $cmd";
        system("$cd && $cmd") == 0 or die "httpd: $cmd failed";
    }

    my $cmd = qq(./configure $self->{MP_AP_CONFIGURE});
    debug "Running $cmd";
    system("$cd && $cmd") == 0 or die "httpd: $cmd failed";

    # Got to build in srclib/* early to have generated files present.
    my $srclib = File::Spec->catfile($self->{MP_AP_PREFIX}, 'srclib');
    $cd = qq(cd $srclib);
    $cmd = qq(make);
    debug "Building srclib in $srclib";
    system("$cd && $cmd") == 0 or die "srclib: $cmd failed";
}

#--- Perl Config stuff ---

my %gtop_config = ();
sub find_gtop {
    my $self = shift;

    return %gtop_config if %gtop_config;

    if (%gtop_config = find_gtop_config()) {
        return %gtop_config;
    }

    if ($self->find_dlfile('gtop')) {
        $gtop_config{ldopts} = $self->gtop_ldopts_old();
        $gtop_config{ccopts} = '';
        return %gtop_config;
    }

    return ();
}

sub find_gtop_config {
    my %c = ();

    my $ver_2_5_plus = 0;
    if (system('pkg-config --exists libgtop-2.0') == 0) {
        # 2.x
        chomp($c{ccopts} = qx|pkg-config --cflags libgtop-2.0|);
        chomp($c{ldopts} = qx|pkg-config --libs   libgtop-2.0|);

        # 2.0.0 bugfix
        chomp(my $libdir = qx|pkg-config --variable=libdir libgtop-2.0|);
        $c{ldopts} =~ s|\$\(libdir\)|$libdir|;

        chomp($c{ver} = qx|pkg-config --modversion libgtop-2.0|);
        ($c{ver_maj}, $c{ver_min}) = split /\./, $c{ver};
        $ver_2_5_plus++ if $c{ver_maj} == 2 && $c{ver_min} >= 5;

        if ($ver_2_5_plus) {
            # some headers were removed in libgtop 2.5.0 so we need to
            # be able to exclude them at compile time
            $c{ccopts} .= ' -DGTOP_2_5_PLUS';
        }

    }
    elsif (system('gnome-config --libs libgtop') == 0) {
        chomp($c{ccopts} = qx|gnome-config --cflags libgtop|);
        chomp($c{ldopts} = qx|gnome-config --libs   libgtop|);

        # buggy ( < 1.0.9?) versions fixup
        $c{ccopts} =~ s|^/|-I/|;
        $c{ldopts} =~ s|^/|-L/|;
    }

    # starting from 2.5.0 'pkg-config --cflags libgtop-2.0' already
    # gives us all the cflags that are needed
    if ($c{ccopts} && !$ver_2_5_plus) {
        chomp(my $ginc = `glib-config --cflags`);
        $c{ccopts} .= " $ginc";
    }

    if (%c) {
        $c{ccopts} = " $c{ccopts}";
        $c{ldopts} = " $c{ldopts}";
    }

    return %c;
}

my @Xlib = qw(/usr/X11/lib /usr/X11R6/lib);

sub gtop_ldopts_old {
    my $self = shift;
    my $xlibs = "";

    my ($path) = $self->find_dlfile('Xau', @Xlib);
    if ($path) {
        $xlibs = "-L$path -lXau";
    }

    if ($self->find_dlfile('intl')) {
        $xlibs .= ' -lintl';
    }

    return " -lgtop -lgtop_sysdeps -lgtop_common $xlibs";
}

sub gtop_ldopts {
    exists $gtop_config{ldopts} ? $gtop_config{ldopts} : '';
}

sub gtop_ccopts {
    exists $gtop_config{ccopts} ? $gtop_config{ccopts} : '';
}

sub ldopts {
    my ($self) = @_;

    my $config = tied %Config;
    my $ldflags = $config->{ldflags};

    if (WIN32) {
        $config->{ldflags} = ''; #same as lddlflags
    }
    elsif (DARWIN) {
        #not sure how this can happen, but it shouldn't
        my @bogus_flags = ('flat_namespace', 'bundle', 'undefined suppress');
        for my $flag (@bogus_flags) {
            $config->{ldflags} =~ s/-$flag\s*//;
        }
    }

    my $ldopts = ExtUtils::Embed::ldopts();
    chomp $ldopts;

    my $ld = $self->perl_config('ld');

    if (HPUX && $ld eq 'ld') {
        while ($ldopts =~ s/-Wl,(\S+)/$1/) {
            my $cp = $1;
            (my $repl = $cp) =~ s/,/ /g;
            $ldopts =~ s/\Q$cp/$repl/;
        }
    }

    if ($self->{MP_USE_GTOP}) {
        $ldopts .= $self->gtop_ldopts;
    }

    $config->{ldflags} = $ldflags; #reset

    # on Irix mod_perl.so needs to see the libperl.so symbols, which
    # requires the -exports option immediately before -lperl.
    if (IRIX) {
        ($ldopts =~ s/-lperl\b/-exports -lperl/)
            or warn "Failed to fix Irix symbol exporting\n";
    }

    $ldopts;
}

my $Wall =
  "-Wall -Wmissing-prototypes -Wstrict-prototypes -Wmissing-declarations";

# perl v5.6.1 and earlier produces lots of warnings, so we can't use
# -Werror with those versions.
$Wall .= " -Werror" if $] >= 5.006002;

sub ap_ccopts {
    my ($self) = @_;
    my $ccopts = "-DMOD_PERL";

    if ($self->{MP_USE_GTOP}) {
        $ccopts .= " -DMP_USE_GTOP";
        $ccopts .= $self->gtop_ccopts;
    }

    if ($self->{MP_MAINTAINER}) {
        $self->{MP_DEBUG} = 1;
        if ($self->perl_config('gccversion')) {
            #same as --with-maintainter-mode
            $ccopts .= " $Wall";
        }

        if (!OPENBSD &&
            $self->has_gcc_version('3.3.2') && 
            $ccopts !~ /declaration-after-statement/) {
            debug "Adding -Wdeclaration-after-statement to ccopts";
            $ccopts .= " -Wdeclaration-after-statement";
        }
    }

    if ($self->{MP_COMPAT_1X}) {
        $ccopts .= " -DMP_COMPAT_1X";
    }

    if ($self->{MP_DEBUG}) {
        $self->{MP_TRACE} = 1;
        my $win32_flags = MSVC  ? '-Od -MD -Zi' : '';
        my $debug_flags = WIN32 ? $win32_flags : '-g';
        $ccopts .= " $debug_flags" unless $Config{optimize} =~ /$debug_flags/;
        $ccopts .= ' -DMP_DEBUG';
    }

    if ($self->{MP_CCOPTS}) {
        $ccopts .= " $self->{MP_CCOPTS}";
    }

    if ($self->{MP_TRACE}) {
        $ccopts .= " -DMP_TRACE";
    }

    if ($self->has_gcc_version('5.0.0') && $ccopts !~ /-fgnu89-inline/) {
        $ccopts .= " -fgnu89-inline";
    }

    if ($self->has_clang && $ccopts !~ /-std=gnu89/) {
        $ccopts .= " -std=gnu89";
    }

    # make sure apr.h can be safely included
    # for example Perl's included -D_GNU_SOURCE implies
    # -D_LARGEFILE64_SOURCE on linux, but this won't happen on
    # Solaris, so we need apr flags living in apxs' EXTRA_CPPFLAGS
    my $extra_cppflags = $self->apxs_extra_cppflags;
    $ccopts .= " " . $extra_cppflags;

    # Make sure the evil AP_DEBUG is not defined when building mod_perl
    $ccopts =~ s/ ?-DAP_DEBUG\b//;

    $ccopts;
}

sub has_gcc_version {
    my $self = shift;
    my $requested_version = shift;

    my $has_version = $self->perl_config('gccversion');

    return 0 unless $has_version;

    #Only interested in leading version digits
    $has_version =~ s/^([0-9.]+).*/$1/;

    my @tuples = split /\./, $has_version, 3;
    my @r_tuples = split /\./, $requested_version, 3;
    
    return cmp_tuples(\@tuples, \@r_tuples) == 1;
}

sub has_clang {
    my $self = shift;

    my $has_version = $self->perl_config('gccversion');

    return 0 unless $has_version;

    return $has_version =~ m/Clang/;
}

sub cmp_tuples {
    my ($num_a, $num_b) = @_;

    while (@$num_a && @$num_b) {
        my $cmp = shift @$num_a <=> shift @$num_b;
        return $cmp if $cmp;
    }

    return @$num_a <=> @$num_b;
}
    
sub perl_ccopts {
    my $self = shift;

    my $cflags = $self->strip_lfs(" $Config{ccflags} ");

    my $fixup = \&{"ccopts_$^O"};
    if (defined &$fixup) {
        $fixup->(\$cflags);
    }

    if (WIN32 and $self->{MP_DEBUG}) {
        #only win32 has -DDEBUGGING in both optimize and ccflags
        my $optim = $Config{optimize};

        unless ($optim =~ /-DDEBUGGING/) {
            $cflags =~ s/$optim//;
       }
    }

    if (CYGWIN) {
        $cflags .= " -DCYGWIN ";
    }

    $cflags;
}

sub ccopts_hpux {
    my $cflags = shift;
    return if $Config{cc} eq 'gcc'; #XXX?
    return if $$cflags =~ /(-Ae|\+e)/;
    $$cflags .= " -Ae ";
}

# XXX: there could be more, but this is just for cosmetics
my %cflags_dups = map { $_ => 1 } qw(-D_GNU_SOURCE -D_REENTRANT);
sub ccopts {
    my ($self) = @_;

    my $cflags = $self->perl_ccopts . ExtUtils::Embed::perl_inc() .
                 $self->ap_ccopts;

    # remove duplicates of certain cflags coming from perl and ap/apr
    my @cflags = ();
    my %dups    = ();
    for (split /\s+/, $cflags) {
        if ($cflags_dups{$_}) {
            next if $dups{$_};
            $dups{$_}++;
        }
        push @cflags, $_;
    }
    $cflags = "@cflags";

    $cflags;
}

sub ldopts_prefix {
    my $self = shift;
    $self->perl_config('ld') eq 'ld' ? '' : "-Wl,";
}

sub perl_config_optimize {
    my ($self, $val) = @_;

    $val ||= $Config{optimize};

    if ($self->{MP_DEBUG}) {
        return ' ' unless $Config{ccflags} =~ /-DDEBUGGING/;
    }

    $val;
}

sub perl_config_ld {
    my ($self, $val) = @_;

    $val ||= $Config{ld};

    basename $val; #bleedperl hpux value is /usr/bin/ld !
}

sub perl_config_lddlflags {
    my ($self, $val) = @_;

    if ($self->{MP_DEBUG}) {
        if (MSVC) {
            unless ($val =~ s/-release/-debug/) {
                $val .= ' -debug';
            }
        }
    }

    if (AIX) {
        my $Wl = $self->ldopts_prefix;

        # it's useless to import symbols from libperl.so this way,
        # because perl.exp is incomplete. a better way is to link
        # against -lperl which has all the symbols
        $val =~ s|${Wl}-bI:\$\(PERL_INC\)/perl\.exp||;
        # also in the case of Makefile.modperl PERL_INC is defined

        # this works with at least ld(1) on powerpc-ibm-aix5.1.0.0:
        # -berok ignores symbols resolution problems (they will be
        #        resolved at run-time
        # -brtl prepares the object for run-time loading
        # LDFLAGS already inserts -brtl
        $val .= " ${Wl}-berok";
        # XXX: instead of -berok, could make sure that we have:
        #   -Lpath/to/CORE -lperl
        #   -bI:$path/apr.exp -bI:$path/aprutil.exp -bI:$path/httpd.exp
        #   -bI:$path/modperl_*.exp 
        # - don't import modperl_*.exp in Makefile.modperl which
        #   exports -bE:$path/modperl_*.exp
        # - can't rely on -bI:$path/perl.exp, because it's incomplete,
        #   use -lperl instead
        # - the issue with using apr/aprutil/httpd.exp is to pick the
        #   right path if httpd wasn't yet installed
    }

    $val;
}

sub perl_config {
    my ($self, $key) = @_;

    my $val = $Config{$key} || '';

    my $method = \&{"perl_config_$key"};
    if (defined &$method) {
        return $method->($self, $val);
    }

    return $val;
}

sub find_in_inc {
    my $name = shift;
    for (@INC) {
        my $file;
        if (-e ($file = "$_/auto/Apache2/$name")) {
            return $file;
        }
    }
}

sub libpth {
    my $self = shift;
    $self->{libpth} ||= [split /\s+/, $Config{libpth}];
    return wantarray ? @{ $self->{libpth} } : $self->{libpth};
}

sub find_dlfile {
    my ($self, $name) = (shift, shift);

    require DynaLoader;
    require AutoLoader; #eek

    my $found = 0;
    my $loc = "";
    my (@path) = ($self->libpth, @_);

    for (@path) {
        if ($found = DynaLoader::dl_findfile($_, "-l$name")) {
            $loc = $_;
            last;
        }
    }

    return wantarray ? ($loc, $found) : $found;
}

sub find_dlfile_maybe {
    my ($self, $name) = @_;

    my $path = $self->libpth;

    my @maybe;
    my $lib = 'lib' . $name;

    for (@$path) {
        push @maybe, grep { ! -l $_ } <$_/$lib.*>;
    }

    return \@maybe;
}

sub lib_check {
    my ($self, $name) = @_;
    return unless $self->perl_config('libs') =~ /$name/;

    return if $self->find_dlfile($name);

    my $maybe = $self->find_dlfile_maybe($name);
    my $suggest = @$maybe ? 
        "You could just symlink it to $maybe->[0]" :
        'You might need to install Perl from source';
    $self->phat_warn(<<EOF);
Your Perl is configured to link against lib$name,
  but lib$name.so was not found.
  $suggest
EOF
}

#--- user interaction ---

sub prompt {
    my ($self, $q, $default) = @_;
    return $default if $self->{MP_PROMPT_DEFAULT};
    require ExtUtils::MakeMaker;
    ExtUtils::MakeMaker::prompt($q, $default);
}

sub prompt_y {
    my ($self, $q) = @_;
    $self->prompt($q, 'y') =~ /^y/i;
}

sub prompt_n {
    my ($self, $q) = @_;
    $self->prompt($q, 'n') =~ /^n/i;
}

sub phat_warn {
    my ($self, $msg, $abort) = @_;
    my $level = $abort ? 'ERROR' : 'WARNING';
    warn <<EOF;
************* $level *************

  $msg

************* $level *************
EOF
    if ($abort) {
        exit 1;
    }
    else {
        sleep 5;
    }
}

#--- constructors ---

my $bpm = 'Apache2/BuildConfig.pm';

sub build_config {
    my $self = shift;
    my $bpm_mtime = 0;

    $bpm_mtime = (stat _)[9] if $INC{$bpm} && -e $INC{$bpm};

    if (-e "lib/$bpm" and (stat _)[9] > $bpm_mtime) {
        #reload if Makefile.PL has regenerated
        unshift @INC, 'lib';
        delete $INC{$bpm};
        eval { require Apache2::BuildConfig; };
        shift @INC;
    }
    else {
        eval { require Apache2::BuildConfig; };
    }

    return bless {}, (ref($self) || $self) if $@;
    return Apache2::BuildConfig->new;
}

sub new {
    my $class = shift;

    my $self = bless {
        cwd        => Cwd::fastcwd(),
        MP_LIBNAME => 'mod_perl',
        MP_APXS    => undef, # so we know we haven't tried to set it yet
        @_,
    }, $class;

    $self->{MP_APR_LIB} = 'aprext';

    ModPerl::BuildOptions->init($self) if delete $self->{init};

    $self;
}

sub DESTROY {}

my %default_files = (
    'build_config' => 'lib/Apache2/BuildConfig.pm',
    'ldopts'       => 'src/modules/perl/ldopts',
    'makefile'     => 'src/modules/perl/Makefile',
);

sub clean_files {
    my $self = shift;
    [sort map { $self->default_file($_) } keys %default_files];
}

sub default_file {
    my ($self, $name, $override) = @_;
    my $key = join '_', 'file', $name;
    $self->{$key} ||= ($override || $default_files{$name});
}

sub file_path {
    my $self = shift;

    # work around when Apache2::BuildConfig has not been created yet
    return unless $self && $self->{cwd};

    my @files = map { m:^/: ? $_ : join('/', $self->{cwd}, $_) } @_;
    return wantarray ? @files : $files[0];
}

sub freeze {
    require Data::Dumper;
    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Sortkeys = 1;
    my $data = Data::Dumper::Dumper(shift);
    chomp $data;
    $data;
}

sub save_ldopts {
    my ($self, $file) = @_;

    $file ||= $self->default_file('ldopts', $file);
    my $ldopts = $self->ldopts;

    open my $fh, '>', $file or die "open $file: $!";
    print $fh "#!/bin/sh\n\necho $ldopts\n";
    close $fh;
    chmod 0755, $file;
}

sub noedit_warning_hash {
    ModPerl::Code::noedit_warning_hash(__PACKAGE__);
}

sub save {
    my ($self, $file) = @_;

    delete $INC{$bpm};

    $file ||= $self->default_file('build_config');
    $file = $self->file_path($file);

    my $obj = $self->freeze;
    $obj =~ s/^\s{9}//mg;
    $obj =~ s/^/    /;

    open my $fh, '>', $file or die "open $file: $!";

    #work around autosplit braindeadness
    my $package = 'package Apache2::BuildConfig';

    print $fh noedit_warning_hash();

    print $fh <<EOF;
$package;

use Apache2::Build ();

sub new {
$obj;
}

1;
EOF

    close $fh or die "failed to write $file: $!";
}

sub rebuild {
    my $self = __PACKAGE__->build_config;
    my @opts = map { qq[$_='$self->{$_}'] } sort grep /^MP_/,  keys %$self;
    my $command = "perl Makefile.PL @opts";
    print "Running: $command\n";
    system $command;
}
# % perl -MApache2::Build -e rebuild
*main::rebuild = \&rebuild if $0 eq '-e';

#--- attribute access ---

sub is_dynamic { shift->{MP_USE_DSO} }

sub default_dir {
    my $build = shift->build_config;

    return $build->dir || '../apache_x.x/src';
}

sub dir {
    my ($self, $dir) = @_;

    if ($dir) {
        for (qw(ap_includedir)) {
            delete $self->{$_};
        }
        if ($dir =~ m:^\.\.[/\\]:) {
            $dir = "$self->{cwd}/$dir";
        }
        $self->{dir} = $dir;
    }

    return $self->{dir} if $self->{dir};

    # be careful with the guesswork, or may pick up some wrong headers
    if (IS_MOD_PERL_BUILD && $self->{MP_AP_PREFIX}) {
        my $build = $self->build_config;

        if (my $bdir = $build->{'dir'}) {
            for ($bdir, "../$bdir", "../../$bdir") {
                if (-d $_) {
                    $dir = $_;
                    last;
                }
            }
        }
    }

    $dir ||= $self->{MP_AP_PREFIX};

# we no longer install Apache headers, so don't bother looking in @INC
# might end up finding 1.x headers anyhow
#    unless ($dir and -d $dir) {
#        for (@INC) {
#            last if -d ($dir = "$_/auto/Apache2/include");
#        }
#    }
    return $self->{dir} = $dir ? canonpath(rel2abs $dir) : undef;
}

#--- finding apache *.h files ---

sub find {
    my $self = shift;
    my %seen = ();
    my @dirs = ();

    for my $src_dir ($self->dir,
                     $self->default_dir,
                     '../httpd-2.0')
      {
          next unless $src_dir;
          next unless (-d $src_dir || -l $src_dir);
          next if $seen{$src_dir}++;
          push @dirs, $src_dir;
          #$modified{$src_dir} = (stat($src_dir))[9];
      }

    return @dirs;
}

sub ap_includedir  {
    my ($self, $d) = @_;

    return $self->{ap_includedir}
      if $self->{ap_includedir} and -d $self->{ap_includedir};

    return unless $d ||= $self->apxs('-q' => 'INCLUDEDIR') || $self->dir;

    if (-e "$d/include/ap_release.h") {
        return $self->{ap_includedir} = "$d/include";
    }

    $self->{ap_includedir} = $d;
}

# This is necessary for static builds that needs to make a
# difference between where the apache headers are (to build
# against) and where they will be installed (to install our
# own headers alongside)
#
# ap_exp_includedir is where apache is going to install its
# headers to
sub ap_exp_includedir {
    my ($self) = @_;

    return $self->{ap_exp_includedir} if $self->{ap_exp_includedir};

    my $build_vars = File::Spec->catfile($self->{MP_AP_PREFIX}, 
                                         qw(build config_vars.mk));
    open my $vars, "<$build_vars" or die "Couldn't open $build_vars $!";
    my $ap_exp_includedir;
    while (<$vars>) {
        if (/exp_includedir\s*=\s*(.*)/) {
            $ap_exp_includedir = $1;
            last;
        }
    }

    $self->{ap_exp_includedir} = $ap_exp_includedir;
}

sub install_headers_dir {
    my ($self) = @_;
    if ($self->should_build_apache) {
        return $self->ap_exp_includedir();
    }
    else {
        return $self->ap_includedir();
    }
}


# where apr-config and apu-config reside
sub apr_bindir {
    my ($self) = @_;

    $self->apr_config_path unless $self->{apr_bindir};
    $self->{apr_bindir};
}

sub apr_generation {
    my ($self) = @_;
    return $self->httpd_version_as_int =~ m/2[1-9]\d+/ ? 1 : 0;
}

# returns an array of apr/apu linking flags (--link-ld --libs) if found
# an empty array otherwise
my @apru_link_flags = ();
sub apru_link_flags {
    my ($self) = @_;

    return @apru_link_flags if @apru_link_flags;

    # first use apu_config_path and then apr_config_path in order to
    # resolve the symbols right during linking
    for ($self->apu_config_path, $self->apr_config_path) {
        my $flags = '--link-ld --libs';
        $flags .= ' --ldflags' unless (WIN32);
        if (my $link = $_ && -x $_ && qx{$_ $flags}) {
            chomp $link;

            # Change '/path/to/libanything.la' to '-L/path/to -lanything'
            if (CYGWIN) {
                $link =~ s|(\S*)/lib([^.\s]+)\.\S+|-L$1 -l$2|g;
            }

            if ($self->httpd_is_source_tree) {
                my @libs;
                while ($link =~ m/-L(\S+)/g) {
                    my $dir = File::Spec->catfile($1, '.libs');
                    push @libs, $dir if -d $dir;
                }
                push @apru_link_flags, join ' ', map { "-L$_" } @libs;
            }
            push @apru_link_flags, $link;
        }
    }

    return @apru_link_flags;
}

sub apr_config_path {
    shift->apru_config_path("apr");
}

sub apu_config_path {
    shift->apru_config_path("apu");
}

sub apru_config_path {
    my ($self, $what) = @_;

    my $key = "${what}_config_path"; # apr_config_path
    my $mp_key = "MP_" . uc($what) . "_CONFIG"; # MP_APR_CONFIG
    my $bindir = uc($what) . "_BINDIR"; # APR_BINDIR

    return $self->{$key} if $self->{$key} and -x $self->{$key};

    if (exists $self->{$mp_key} and -x $self->{$mp_key}) {
        $self->{$key} = $self->{$mp_key};
    }

    my $config = $self->apr_generation ? "$what-1-config" : "$what-config";

    if (!$self->{$key}) {
        my @tries = ();
        if ($self->httpd_is_source_tree) {
            for my $base (grep defined $_, $self->dir) {
                push @tries, grep -d $_,
                    map catdir($base, "srclib", $_), qw(apr apr-util);
            }

            # Check for MP_AP_CONFIGURE="--with-apr[-util]=DIR|FILE"
            my $what_long = ($what eq 'apu') ? 'apr-util' : 'apr';
            if ($self->{MP_AP_CONFIGURE} &&
                $self->{MP_AP_CONFIGURE} =~ /--with-${what_long}=(\S+)/) {
                my $dir = $1;
                $dir = dirname $dir if -f $dir;
                push @tries, grep -d $_, $dir, catdir $dir, 'bin';
            }
        }
        else {
            push @tries, grep length,
                map $self->apxs(-q => $_), $bindir, "BINDIR";
            push @tries, catdir $self->{MP_AP_PREFIX}, "bin"
                if exists $self->{MP_AP_PREFIX} and -d $self->{MP_AP_PREFIX};
        }

        @tries = map { catfile $_, $config } @tries;
        if (WIN32) {
            my $ext = '.bat';
            for (@tries) {
                $_ .= $ext if ($_ and $_ !~ /$ext$/);
            }
        }

        for my $try (@tries) {
            next unless -x $try;
            $self->{$key} = $try;
        }
    }

    $self->{$key} ||= Apache::TestConfig::which($config);

    # apr_bindir makes sense only if httpd/apr is installed, if we are
    # building against the source tree we can't link against
    # apr/aprutil libs
    unless ($self->httpd_is_source_tree) {
        $self->{apr_bindir} = $self->{$key}
            ? dirname $self->{$key}
            : '';
        }

    $self->{$key};
}

sub apr_includedir {
    my ($self) = @_;

    return $self->{apr_includedir}
        if $self->{apr_includedir} and -d $self->{apr_includedir};

    my $incdir;
    my $apr_config_path = $self->apr_config_path;

    if ($apr_config_path) {
        my $httpd_version = $self->httpd_version;
        chomp($incdir = `$apr_config_path --includedir`);
    }

    unless ($incdir and -d $incdir) {
        # falling back to the default when apr header files are in the
        # same location as the httpd header files
        $incdir = $self->ap_includedir;
    }

    my @tries = ($incdir);
    if ($self->httpd_is_source_tree) {
        my $path = catdir $self->dir, "srclib", "apr", "include";
        push @tries, $path if -d $path;
    }


    for (@tries) {
        next unless $_ && -e catfile $_, "apr.h";
        $self->{apr_includedir} = $_;
        last;
    }

    unless ($self->{apr_includedir}) {
        error "Can't find apr include/ directory,",
            "use MP_APR_CONFIG=/path/to/apr-config";
        exit 1;
    }

    $self->{apr_includedir};
}

#--- parsing apache *.h files ---

sub mmn_eq {
    my ($class, $dir) = @_;

    return 1 if WIN32; #just assume, till Apache2::Build works under win32

    my $instsrc;
    {
        local @INC = grep { !/blib/ } @INC;
        my $instdir;
        for (@INC) { 
            last if -d ($instdir = "$_/auto/Apache2/include");
        }
        $instsrc = $class->new(dir => $instdir);
    }
    my $targsrc = $class->new($dir ? (dir => $dir) : ());

    my $inst_mmn = $instsrc->module_magic_number;
    my $targ_mmn = $targsrc->module_magic_number;

    unless ($inst_mmn && $targ_mmn) {
        return 0;
    }
    if ($inst_mmn == $targ_mmn) {
        return 1;
    }
    print "Installed MMN $inst_mmn does not match target $targ_mmn\n";

    return 0;
}

sub module_magic_number {
    my $self = shift;

    return $self->{mmn} if $self->{mmn};

    my $d = $self->ap_includedir;

    return 0 unless $d;

    #return $mcache{$d} if $mcache{$d};
    my $fh;
    for (qw(ap_mmn.h http_config.h)) {
        last if open $fh, "$d/$_";
    }
    return 0 unless $fh;

    my $n;
    my $mmn_pat = join '|', qw(MODULE_MAGIC_NUMBER_MAJOR MODULE_MAGIC_NUMBER);
    while(<$fh>) {
        if(s/^\#define\s+($mmn_pat)\s+(\d+).*/$2/) {
           chomp($n = $_);
           last;
       }
    }
    close $fh;

    $self->{mmn} = $n
}

sub fold_dots {
    my $v = shift;
    $v =~ s/\.//g;
    $v .= '0' if length $v < 3;
    $v;
}

sub httpd_version_as_int {
    my ($self, $dir) = @_;
    my $v = $self->httpd_version($dir);
    fold_dots($v);
}

sub httpd_version_cache {
    my ($self, $dir, $v) = @_;
    return '' unless $dir;
    $self->{httpd_version}->{$dir} = $v if $v;
    $self->{httpd_version}->{$dir};
}

sub httpd_version {
    my ($self, $dir) = @_;

    return unless $dir = $self->ap_includedir($dir);

    if (my $v = $self->httpd_version_cache($dir)) {
        return $v;
    }

    my $header = "$dir/ap_release.h";
    open my $fh, $header or do {
        error "Unable to open $header: $!";
        return undef;
    };

    my $version;

    while (<$fh>) {
        #now taking bets on how many friggin times this will change
        #over the course of apache 2.0.  1.3 changed it at least a half
        #dozen times.  hopefully it'll stay in the same file at least.
        if (/^\#define\s+AP_SERVER_MAJORVERSION\s+\"(\d+)\"/) {
            #XXX could be more careful here.  whatever.  see above.
            my $major = $1;
            my $minor = (split /\s+/, scalar(<$fh>))[-1];
            my $patch = (split /\s+/, scalar(<$fh>))[-1];
            $version = join '.', $major, $minor, $patch;
            $version =~ s/\"//g;
            last;
        }
        elsif (/^\#define\s+AP_SERVER_BASEREVISION\s+\"(.*)\"/) {
            $version = $1;
            last;
        }
        elsif(/^\#define\s+AP_SERVER_MAJORVERSION_NUMBER\s+(\d+)/) {
            # new 2.1 config
            my $major = $1;
            my $minor = (split /\s+/, scalar(<$fh>))[-1];
            my $patch = (split /\s+/, scalar(<$fh>))[-1];

            my ($define, $macro, $dev) = (split /\s+/, scalar(<$fh>));
            
            if ($macro =~ /AP_SERVER_DEVBUILD_BOOLEAN/ && $dev eq '1') {
                $dev = "-dev";
            }
            else {
                $dev = "";   
            }

            $version = join '.', $major, $minor, "$patch$dev";
            $version =~ s/\"//g;
            last;
        }
    }

    close $fh;

    debug "parsed version $version from ap_release.h";

    $self->httpd_version_cache($dir, $version);
}

my %wanted_apr_config = map { $_, 1} qw(
    HAS_THREADS HAS_DSO HAS_MMAP HAS_RANDOM HAS_SENDFILE
    HAS_LARGE_FILES HAS_INLINE HAS_FORK
);

sub get_apr_config {
    my $self = shift;

    return $self->{apr_config} if $self->{apr_config};

    my $header = catfile $self->apr_includedir, "apr.h";
    open my $fh, $header or do {
        error "Unable to open $header: $!";
        return undef;
    };

    my %cfg;
    while (<$fh>) {
        next unless s/^\#define\s+APR_((HAVE|HAS|USE)_\w+)/$1/;
        chomp;
        my ($name, $val) = split /\s+/, $_, 2;
        next unless $wanted_apr_config{$name};
        $val =~ s/\s+$//;
        next unless $val =~ /^\d+$/;
        $cfg{$name} = $val;
    }

    $self->{apr_config} = \%cfg;
}

#--- generate Makefile ---

sub canon_make_attr {
    my ($self, $name) = (shift, shift);

    my $attr = join '_', 'MODPERL', uc $name;
    $self->{$attr} = "@_";
    "$attr = $self->{$attr}\n\n";
}

sub xsubpp {
    my $self = shift;
    my $xsubpp = join ' ', '$(MODPERL_PERLPATH)',
      '$(MODPERL_PRIVLIBEXP)/ExtUtils/xsubpp',
        '-typemap', '$(MODPERL_PRIVLIBEXP)/ExtUtils/typemap';

    my $typemap = $self->file_path('lib/typemap');
    if (-e $typemap) {
        $xsubpp .= join ' ',
          ' -typemap', $typemap;
    }

    $xsubpp;
}

sub make_xs {
    my ($self, $fh) = @_;

    print $fh $self->canon_make_attr(xsubpp => $self->xsubpp);

    return [] unless $self->{XS};

    my @files;
    my @xs_targ;

    foreach my $name (sort keys %{ $self->{XS} }) {
        my $xs = $self->{XS}->{$name};
        #Foo/Bar.xs => Foo_Bar.c
        (my $c = $xs) =~ s:.*?WrapXS/::;
        $c =~ s:/:_:g;
        $c =~ s:\.xs$:.c:;

        push @files, $c;

        push @xs_targ, <<EOF;
$c: $xs
\t\$(MODPERL_XSUBPP) $xs > \$*.xsc && \$(MODPERL_MV) \$*.xsc \$@

EOF
    }

    my %o = (xs_o_files => 'o', xs_o_pic_files => 'lo');

    for my $ext (qw(xs_o_files xs_o_pic_files)) {
        print $fh $self->canon_make_attr($ext, map {
            (my $file = $_) =~ s/c$/$o{$ext}/; $file;
        } @files);
    }

    print $fh $self->canon_make_attr(xs_clean_files => @files);

    \@xs_targ;
}

#when we use a bit of MakeMaker, make it use our values for these vars
my %perl_config_pm_alias = (
    ABSPERL      => 'perlpath',
    ABSPERLRUN   => 'perlpath',
    PERL         => 'perlpath',
    PERLRUN      => 'perlpath',
    PERL_LIB     => 'privlibexp',
    PERL_ARCHLIB => 'archlibexp',
);

my $mm_replace = join '|', keys %perl_config_pm_alias;

# get rid of dups
my %perl_config_pm_alias_values = reverse %perl_config_pm_alias;
my @perl_config_pm_alias_values = keys %perl_config_pm_alias_values;

my @perl_config_pm = sort(@perl_config_pm_alias_values, qw(cc cpprun
    rm ranlib lib_ext obj_ext cccdlflags lddlflags optimize));

sub mm_replace {
    my $val = shift;
    $$val =~ s/\(($mm_replace)\)/(MODPERL_\U$perl_config_pm_alias{$1})/g;
}

#help prevent warnings
my @mm_init_vars = (BASEEXT => '');

sub make_tools {
    my ($self, $fh) = @_;

    for (@perl_config_pm) {
        print $fh $self->canon_make_attr($_, $self->perl_config($_));
    }

    require ExtUtils::MakeMaker;
    my $mm = bless { @mm_init_vars }, 'MM';

    # Fake initialize MakeMaker
    foreach my $m (qw(init_main init_others init_tools)) {
        $mm->$m() if $mm->can($m);
    }

    for (qw(rm_f mv ld ar cp test_f)) {
        my $val = $mm->{"\U$_"};
        if ($val) {
            mm_replace(\$val);
        }
        else {
            $val = $Config{$_};
        }
        print $fh $self->canon_make_attr($_ => $val);
    }
}

sub export_files_MSWin32 {
    my $self = shift;
    my $xs_dir = $self->file_path("xs");
    "-def:$xs_dir/modperl.def";
}

sub export_files_aix {
    my $self = shift;

    my $Wl = $self->ldopts_prefix;
    # there are several modperl_*.exp, not just $(BASEEXT).exp
    # $(BASEEXT).exp resolves to modperl_global.exp
    my $xs_dir = $self->file_path("xs");
    join " ", map "${Wl}-bE:$xs_dir/modperl_$_.exp", qw(inline ithreads);
}

sub dynamic_link_header_default {
    return <<'EOF';
$(MODPERL_LIBNAME).$(MODPERL_DLEXT): $(MODPERL_PIC_OBJS)
	$(MODPERL_RM_F) $@
	$(MODPERL_LD) $(MODPERL_LDDLFLAGS) \
	$(MODPERL_AP_LIBS) \
	$(MODPERL_PIC_OBJS) $(MODPERL_LDOPTS) \
EOF
}

sub dynamic_link_default {
    my $self = shift;

    my $link = $self->dynamic_link_header_default . "\t" . '-o $@';

    my $ranlib = "\t" . '$(MODPERL_RANLIB) $@' . "\n";

    $link .= "\n" . $ranlib unless (DARWIN or OPENBSD);

    $link;
}

sub dynamic_link_MSWin32 {
    my $self = shift;
    my $defs = $self->export_files_MSWin32;
    my $symbols = $self->modperl_symbols_MSWin32;
    return $self->dynamic_link_header_default .
        "\t$defs" .
        ($symbols ? ' \\' . "\n\t-pdb:$symbols" : '') .
        ' -out:$@' . "\n\t" .
        'if exist $(MODPERL_MANIFEST_LOCATION)' . " \\\n\t" .
        'mt /nologo /manifest $(MODPERL_MANIFEST_LOCATION)' . " \\\n\t" .
        '/outputresource:$@;2' . "\n\n";
}

sub dynamic_link_aix {
    my $self = shift;
    my $link = $self->dynamic_link_header_default .
        "\t" . $self->export_files_aix . " \\\n" .
        "\t" . '-o $@' . " \n" .
        "\t" . '$(MODPERL_RANLIB) $@';
}

sub dynamic_link_cygwin {
    my $self = shift;
    return <<'EOF';
$(MODPERL_LIBNAME).$(MODPERL_DLEXT): $(MODPERL_PIC_OBJS)
	$(MODPERL_RM_F) $@
	$(MODPERL_CC) -shared -o $@ \
	-Wl,--out-implib=$(MODPERL_LIBNAME).dll.a \
	-Wl,--export-all-symbols -Wl,--enable-auto-import \
	-Wl,--enable-auto-image-base -Wl,--stack,8388608 \
	$(MODPERL_PIC_OBJS) \
	$(MODPERL_LDDLFLAGS) $(MODPERL_LDOPTS) \
	$(MODPERL_AP_LIBS)
	$(MODPERL_RANLIB) $@
EOF
}

sub dynamic_link {
    my $self = shift;
    my $link = \&{"dynamic_link_$^O"};
    $link = \&dynamic_link_default unless defined &$link;
    $link->($self);
}

# Returns the link flags for the apache shared core library
my $apache_corelib_cygwin;
sub apache_corelib_cygwin {
    return $apache_corelib_cygwin if $apache_corelib_cygwin;

    my $self = shift;
    my $mp_src = "$self->{cwd}/src/modules/perl";
    my $core = 'httpd2core';

    # There's a problem with user-installed perl on cygwin.
    # MakeMaker doesn't know about the .dll.a libs and warns
    # about missing -lhttpd2core. "Fix" it by copying
    # the lib and adding .a suffix.
    # For the static build create a soft link, because libhttpd2core.dll.a
    # doesn't exist at this time.
    if ($self->is_dynamic) {
        my $libpath = $self->apxs(-q => 'exp_libdir');
        File::Copy::copy("$libpath/lib$core.dll.a", "$mp_src/lib$core.a");
    } else {
        my $libpath = catdir($self->{MP_AP_PREFIX}, '.libs');
        mkdir $libpath unless -d $libpath;
        qx{touch $libpath/lib$core.dll.a && \
        ln -fs $libpath/lib$core.dll.a $mp_src/lib$core.a};
    }

    $apache_corelib_cygwin = "-L$mp_src -l$core";
}

sub apache_libs_MSWin32 {
    my $self = shift;
    my $prefix = $self->apxs(-q => 'PREFIX') || $self->dir;
    my $lib = catdir $prefix, 'lib';
    opendir(my $dir, $lib) or die qq{Cannot opendir $lib: $!};
    my @libs = map {catfile($lib, $_)}
        grep /^lib(apr|aprutil|httpd)\b\S*?\.lib$/, readdir $dir;
    closedir $dir;
    "@libs";
}

sub apache_libs_cygwin {
    my $self = shift;
    join ' ', $self->apache_corelib_cygwin, $self->apru_link_flags;
}

sub apache_libs {
    my $self = shift;
    my $libs = \&{"apache_libs_$^O"};
    return "" unless defined &$libs;
    $libs->($self);
}

sub modperl_libs_MSWin32 {
    my $self = shift;
    "$self->{cwd}/src/modules/perl/$self->{MP_LIBNAME}.lib";
}

sub modperl_libs_cygwin {
     my $self = shift;
     return '' unless $self->is_dynamic;
     return "-L$self->{cwd}/src/modules/perl -l$self->{MP_LIBNAME}";
}

sub modperl_libs {
    my $self = shift;
    my $libs = \&{"modperl_libs_$^O"};
    return "" unless defined &$libs;
    $libs->($self);
}

sub modperl_libpath_MSWin32 {
    my $self = shift;
    # mod_perl.lib will be installed into MP_AP_PREFIX/lib
    # for use by 3rd party xs modules
    "$self->{cwd}/src/modules/perl/$self->{MP_LIBNAME}.lib";
}

sub modperl_libpath_cygwin {
    my $self = shift;
    "$self->{cwd}/src/modules/perl/$self->{MP_LIBNAME}.dll.a";
}

sub modperl_libpath {
    my $self = shift;
    my $libpath = \&{"modperl_libpath_$^O"};
    return "" unless defined &$libpath;
    $libpath->($self);
}

# returns the directory and name of the aprext lib built under blib/ 
sub mp_apr_blib {
    my $self = shift;
    return unless (my $mp_apr_lib = $self->{MP_APR_LIB});
    my $lib_mp_apr_lib = 'lib' . $mp_apr_lib;
    my @dirs = qw(blib arch auto);
    my $apr_blib = catdir $self->{cwd}, @dirs, $lib_mp_apr_lib;
    my $full_libname = $lib_mp_apr_lib . $Config{lib_ext};
    return ($apr_blib, $full_libname);
}

sub mp_apr_lib_MSWin32 {
    my $self = shift;
    # The MP_APR_LIB will be installed into MP_AP_PREFIX/lib
    # for use by 3rd party xs modules
    my ($dir, $lib) = $self->mp_apr_blib();
    $lib =~ s[^lib(\w+)$Config{lib_ext}$][$1];
    $dir = Win32::GetShortPathName($dir);
    return qq{ -L$dir -l$lib };
}

sub mp_apr_lib_cygwin {
    my $self = shift;
    my ($dir, $lib) = $self->mp_apr_blib();
    $lib =~ s[^lib(\w+)$Config{lib_ext}$][$1];
    my $libs = "-L$dir -l$lib";

    # This is ugly, but is the only way to prevent the "undefined
    # symbols" error
    $libs .= join ' ', '',
        '-L' . catdir($self->perl_config('archlibexp'), 'CORE'), '-lperl';

    $libs;
}

# linking used for the aprext lib used to build APR/APR::*
sub mp_apr_lib {
    my $self = shift;
    my $libs = \&{"mp_apr_lib_$^O"};
    return "" unless defined &$libs;
    $libs->($self);
}

sub modperl_symbols_MSWin32 {
    my $self = shift;
    return "" unless $self->{MP_DEBUG};
    "$self->{cwd}/src/modules/perl/$self->{MP_LIBNAME}.pdb";
}

sub modperl_symbols {
    my $self = shift;
    my $symbols = \&{"modperl_symbols_$^O"};
    return "" unless defined &$symbols;
    $symbols->($self);
}

sub write_src_makefile {
    my $self = shift;
    my $code = ModPerl::Code->new;
    my $path = $code->path;

    my $install = <<'EOI';
install:
EOI
    if (!$self->should_build_apache) {
        $install .= <<'EOI';
# install mod_perl.so
	@$(MKPATH) $(DESTDIR)$(MODPERL_AP_LIBEXECDIR)
	$(MODPERL_TEST_F) $(MODPERL_LIB_DSO) && \
	$(MODPERL_CP) $(MODPERL_LIB_DSO) $(DESTDIR)$(MODPERL_AP_LIBEXECDIR)
EOI
    }

    $install .= <<'EOI';
# install mod_perl .h files
	@$(MKPATH) $(DESTDIR)$(MODPERL_AP_INCLUDEDIR)
	$(MODPERL_CP) $(MODPERL_H_FILES) $(DESTDIR)$(MODPERL_AP_INCLUDEDIR)
EOI

    my $mf = $self->default_file('makefile');

    open my $fh, '>', $mf or die "open $mf: $!";

    print $fh noedit_warning_hash();

    print $fh $self->canon_make_attr('makefile', basename $mf);

    $self->make_tools($fh);

    print $fh $self->canon_make_attr('ap_libs', $self->apache_libs);

    print $fh $self->canon_make_attr('libname', $self->{MP_LIBNAME});
    print $fh $self->canon_make_attr('dlext', 'so'); #always use .so

    if (AIX) {
        my $xs_dir = $self->file_path("xs");
        print $fh "BASEEXT = $xs_dir/modperl_global\n\n";
    }

    my %libs = (
        dso    => "$self->{MP_LIBNAME}.$self->{MODPERL_DLEXT}",
        static => "$self->{MP_LIBNAME}$self->{MODPERL_LIB_EXT}",
    );

    #XXX short-term compat for Apache::TestConfigPerl
    $libs{shared} = $libs{dso};

    foreach my $type (sort keys %libs) {
        my $lib = $libs{$type};
        print $fh $self->canon_make_attr("lib_$type", $libs{$type});
    }

    if (my $symbols = $self->modperl_symbols) {
        print $fh $self->canon_make_attr('lib_symbols', $symbols);
        $install .= <<'EOI';
# install mod_perl symbol file
	@$(MKPATH) $(MODPERL_AP_LIBEXECDIR)
	$(MODPERL_TEST_F) $(MODPERL_LIB_SYMBOLS) && \
	$(MODPERL_CP) $(MODPERL_LIB_SYMBOLS) $(MODPERL_AP_LIBEXECDIR)
EOI
    }

    if ($self->is_dynamic && (my $libs = $self->modperl_libpath)) {
        print $fh $self->canon_make_attr('lib_location', $libs);

        # Visual Studio 8 on Win32 uses manifest files
        if (WIN32) {
            (my $manifest = $libs) =~ s/\.lib$/.so.manifest/;
            print $fh $self->canon_make_attr('manifest_location', $manifest);
        }

        print $fh $self->canon_make_attr('ap_libdir',
            $self->ap_destdir(catdir $self->{MP_AP_PREFIX}, 'lib')
        );

        $install .= <<'EOI';
# install mod_perl.lib
	@$(MKPATH) $(MODPERL_AP_LIBDIR)
	$(MODPERL_TEST_F) $(MODPERL_LIB_LOCATION) && \
	$(MODPERL_CP) $(MODPERL_LIB_LOCATION) $(MODPERL_AP_LIBDIR)
EOI
    }

    my $libperl = join '/',
      $self->perl_config('archlibexp'), 'CORE', $self->perl_config('libperl');

    #this is only used for deps, if libperl has changed, relink mod_perl.so
    #not all perl dists put libperl where it should be, so just leave this
    #out if it isn't in the proper place
    if (-e $libperl) {
        print $fh $self->canon_make_attr('libperl', $libperl);
    }

    for my $method (qw(ccopts ldopts inc)) {
        print $fh $self->canon_make_attr($method, $self->$method());
    }

    for my $method (qw(c_files o_files o_pic_files h_files)) {
        print $fh $self->canon_make_attr($method, @{ $code->$method() });
    }

    my @libs;
    for my $type (sort map { uc } keys %libs) {
        next unless $self->{"MP_USE_$type"};
        # on win32 mod_perl.lib must come after mod_perl.so
        $type eq 'STATIC'
            ? push    @libs, $self->{"MODPERL_LIB_$type"}
            : unshift @libs, $self->{"MODPERL_LIB_$type"};
    }

    print $fh $self->canon_make_attr('lib', "@libs");

    print $fh $self->canon_make_attr('AP_INCLUDEDIR',
        $self->ap_destdir($self->install_headers_dir));

    print $fh $self->canon_make_attr('AP_LIBEXECDIR',
        $self->ap_destdir($self->apxs(-q => 'LIBEXECDIR')));

    my $xs_targ = $self->make_xs($fh);

    print $fh <<'EOF';
MODPERL_CCFLAGS = $(MODPERL_INC) $(MODPERL_CCOPTS) $(MODPERL_OPTIMIZE)

MODPERL_CCFLAGS_SHLIB = $(MODPERL_CCFLAGS) $(MODPERL_CCCDLFLAGS)

MODPERL_OBJS = $(MODPERL_O_FILES) $(MODPERL_XS_O_FILES)

MODPERL_PIC_OBJS = $(MODPERL_O_PIC_FILES) $(MODPERL_XS_O_PIC_FILES)

MKPATH = $(MODPERL_PERLPATH) "-MExtUtils::Command" -e mkpath

all: lib

lib: $(MODPERL_LIB)

EOF

    print $fh $install;

    print $fh <<'EOF' if DMAKE;

.USESHELL :
EOF

    print $fh <<'EOF';

.SUFFIXES: .xs .c $(MODPERL_OBJ_EXT) .lo .i .s

.c.lo:
	$(MODPERL_CC) $(MODPERL_CCFLAGS_SHLIB) \
	-c $< && $(MODPERL_MV) $*$(MODPERL_OBJ_EXT) $*.lo

.c$(MODPERL_OBJ_EXT):
	$(MODPERL_CC) $(MODPERL_CCFLAGS) -c $<

.c.i:
	$(MODPERL_CPPRUN) $(MODPERL_CCFLAGS) -c $< > $*.i

.c.s:
	$(MODPERL_CC) -O -S $(MODPERL_CCFLAGS) -c $<

.xs.c:
	$(MODPERL_XSUBPP) $*.xs >$@

.xs$(MODPERL_OBJ_EXT):
	$(MODPERL_XSUBPP) $*.xs >$*.c
	$(MODPERL_CC) $(MODPERL_CCFLAGS) -c $*.c

.xs.lo:
	$(MODPERL_XSUBPP) $*.xs >$*.c
	$(MODPERL_CC) $(MODPERL_CCFLAGS_SHLIB) \
	-c $*.c && $(MODPERL_MV) $*$(MODPERL_OBJ_EXT) $*.lo

clean:
	$(MODPERL_RM_F) *.a *.so *.xsc \
	$(MODPERL_LIBNAME).exp $(MODPERL_LIBNAME).lib \
	*$(MODPERL_OBJ_EXT) *.lo *.i *.s *.pdb *.manifest \
	$(MODPERL_CLEAN_FILES) \
	$(MODPERL_XS_CLEAN_FILES)

$(MODPERL_OBJS): $(MODPERL_H_FILES) $(MODPERL_MAKEFILE)
$(MODPERL_PIC_OBJS): $(MODPERL_H_FILES) $(MODPERL_MAKEFILE)
$(MODPERL_LIB): $(MODPERL_LIBPERL)

$(MODPERL_LIBNAME)$(MODPERL_LIB_EXT): $(MODPERL_OBJS)
	$(MODPERL_RM_F) $@
	$(MODPERL_AR) crv $@ $(MODPERL_OBJS)
	$(MODPERL_RANLIB) $@

EOF

    print $fh $self->dynamic_link;

    print $fh @$xs_targ;

    print $fh "\n"; # Makefile must end with \n to avoid warnings

    close $fh;
}

#--- generate MakeMaker parameter values ---

sub otherldflags_default {
    my $self = shift;
    # e.g. aix's V:ldflags feeds -brtl and other flags
    $self->perl_config('ldflags');
}

sub otherldflags {
    my $self = shift;
    my $flags = \&{"otherldflags_$^O"};
    return $self->otherldflags_default unless defined &$flags;
    $flags->($self);
}

sub otherldflags_MSWin32 {
    my $self = shift;
    my $flags = $self->otherldflags_default;
    $flags .= ' -pdb:$(INST_ARCHAUTODIR)\$(BASEEXT).pdb' if $self->{MP_DEBUG};
    $flags;
}

sub typemaps {
    my $self = shift;
    my @typemaps = ();

    # XXX: could move here the code from ModPerl::BuildMM
    return [] if IS_MOD_PERL_BUILD;

    # for post install use
    for (@INC) {
        # make sure not to pick mod_perl 1.0 typemap
        my $file = "$_/auto/Apache2/typemap";
        push @typemaps, $file if -e $file;
    }

    return \@typemaps;
}

sub includes {
    my $self = shift;

    my @inc = ();

    unless (IS_MOD_PERL_BUILD) {
        # XXX: what if apxs is not available? win32?
        my $ap_inc = $self->apxs('-q' => 'INCLUDEDIR');
        if ($ap_inc && -d $ap_inc) {
            push @inc, $ap_inc;
            return \@inc;
        }

        # this is fatal
        my $reason = $ap_inc
            ? "path $ap_inc doesn't exist"
            : "apxs -q INCLUDEDIR didn't return a value";
        die "Can't find the mod_perl include dir (reason: $reason)";
    }

    my $os = WIN32 ? 'win32' : 'unix';
    push @inc, $self->file_path("src/modules/perl", "xs");

    push @inc, $self->mp_include_dir;

    unless ($self->httpd_is_source_tree) {
        push @inc, $self->apr_includedir;

        my $apuc = $self->apu_config_path;
        if ($apuc && -x $apuc) {
            chomp(my $apuincs = qx($apuc --includes));
            # win32: /Ipath, elsewhere -Ipath
            $apuincs =~ s{^\s*(-|/)I}{};
            push @inc, $apuincs;
        }

        my $ainc = $self->apxs('-q' => 'INCLUDEDIR');
        if (-d $ainc) {
            push @inc, $ainc;
            return \@inc;
        }
    }

    if ($self->{MP_AP_PREFIX}) {
        my $src = $self->dir;
        for ("$src/modules/perl", "$src/include",
             "$src/srclib/apr/include",
             "$src/srclib/apr-util/include",
             "$src/os/$os")
            {
                push @inc, $_ if -d $_;
            }
    }

    return \@inc;
}

sub inc {
    local $_;
    my @includes = map { "-I$_" } @{ shift->includes };
    "@includes";
}

### Picking the right LFS support flags for mod_perl, by Joe Orton ###
#
# on Unix systems where by default off_t is a "long", a 32-bit integer,
# there are two different ways to get "large file" support, i.e. the
# ability to manipulate files bigger than 2Gb:
#
# 1) you compile using -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64.  This
# makes sys/types.h expose off_t as a "long long", a 64-bit integer, and
# changes the size of a few other types too.  The C library headers
# automatically arrange to expose a correct implementation of functions
# like lseek() which take off_t parameters.
#
# 2) you compile using -D_LARGEFILE64_SOURCE, and use what is called the
# "transitional" interface.  This means that the system headers expose a
# new type, "off64_t", which is a long long, but the size of off_t is not
# changed.   A bunch of new functions like lseek64() are exposed by the C 
# library headers, which take off64_t parameters in place of off_t.
#
# Perl built with -Duselargefiles uses approach (1).
#
# APR HEAD uses (2) by default. APR 0.9 does not by default use either
# approach, but random users can take a httpd-2.0.49 tarball, and do:
#
#   export CPPFLAGS="-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
#   ./configure
#
# to build a copy of apr/httpd which uses approach (1), though this
# isn't really a supported configuration.
#
# The problem that mod_perl has to work around is when you take a
# package built with approach (1), i.e. Perl, and any package which was
# *not* built with (1), i.e. APR, and want to interface between
# them. [1]
#
# So what you want to know is whether APR was built using approach (1)
# or not.  APR_HAS_LARGE_FILES in HEAD just tells you whether APR was
# built using approach (2) or not, which isn't useful in solving this
# problem.
#
# [1]: In some cases, it may be OK to interface between packages which
# use (1) and packages which use (2).  APR HEAD is currently not such a
# case, since the size of apr_ino_t is still changing when
# _FILE_OFFSET_BITS is defined.
#
# If you want to see how this matters, get some httpd function to do at
# the very beginning of main():
#
#   printf("sizeof(request_rec) = %lu, sizeof(apr_finfo_t) = %ul",
#          sizeof(request_rec), sizeof(apr_finfo_t));
#
# and then put the same printf in mod_perl somewhere, and see the
# differences. This is why it is a really terribly silly idea to ever
# use approach (1) in anything other than an entirely self-contained
# application.
#
# there is no conflict if both libraries either have or don't have
# large files support enabled
sub has_large_files_conflict {
    my $self = shift;

    my $apxs_flags = join $self->apxs_extra_cflags, $self->apxs_extra_cppflags;
    my $apr_lfs64  = $apxs_flags      =~ /-D_FILE_OFFSET_BITS=64/;
    my $perl_lfs64 = $Config{ccflags} =~ /-D_FILE_OFFSET_BITS=64/;

    # XXX: we don't really deal with the case where APR was built with
    # -D_FILE_OFFSET_BITS=64 but perl wasn't, since currently we strip
    # only perl's ccflags, not apr's flags. the reason we don't deal
    # with it is that we didn't have such a case yet, but may need to
    # deal with it later

    return 0;
    # $perl_lfs64 ^ $apr_lfs64;
}

# if perl is built with uselargefiles, but apr not, the build won't
# work together as it uses two binary incompatible libraries, so
# reduce the functionality to the greatest common denominator (C code
# will have to make sure to prevent any operations that may rely on
# effects created by uselargefiles, e.g. Off_t=8 instead of Off_t=4)
sub strip_lfs {
    my ($self, $cflags) = @_;
    return $cflags unless $self->has_large_files_conflict();

    my $lf = $Config{ccflags_uselargefiles}
        || '-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64';
    $cflags =~ s/$lf//;
    $cflags;
}

sub define {
    my $self = shift;

    return "";
}

1;

__END__

=head1 NAME

Apache2::Build - Methods for locating and parsing bits of Apache source code

=head1 SYNOPSIS

 use Apache2::Build ();
 my $build = Apache2::Build->new;

 # rebuild mod_perl with build opts from the previous build
 % cd modperl-2.0
 % perl -MApache2::Build -e rebuild

=head1 DESCRIPTION

This module provides methods for locating and parsing bits of Apache
source code.

Since mod_perl remembers what build options were used to build it, you
can use this knowledge to rebuild it using the same options. Simply
chdir to the mod_perl source directory and run:

  % cd modperl-2.0
  % perl -MApache2::Build -e rebuild

If you want to rebuild not yet installed, but already built mod_perl,
run from its root directory:

  % perl -Ilib -MApache2::Build -e rebuild

=head1 METHODS

=over 4

=item new

Create an object blessed into the B<Apache2::Build> class.

 my $build = Apache2::Build->new;

=item dir

Top level directory where source files are located.

 my $dir = $build->dir;
 -d $dir or die "can't stat $dir $!\n";

=item find

Searches for apache source directories, return a list of those found.

Example:

 for my $dir ($build->find) {
    my $yn = prompt "Configure with $dir ?", "y";
    ...
 }

=item inc

Print include paths for MakeMaker's B<INC> argument to
C<WriteMakefile>.

Example:

 use ExtUtils::MakeMaker;

 use Apache2::Build ();

 WriteMakefile(
     'NAME'    => 'Apache2::Module',
     'VERSION' => '0.01',
     'INC'     => Apache2::Build->new->inc,
 );


=item module_magic_number

Return the B<MODULE_MAGIC_NUMBER> defined in the apache source.

Example:

 my $mmn = $build->module_magic_number;

=item httpd_version

Return the server version.

Example:

 my $v = $build->httpd_version;

=item otherldflags

Return other ld flags for MakeMaker's B<dynamic_lib> argument to
C<WriteMakefile>. This might be needed on systems like AIX that need
special flags to the linker to be able to reference mod_perl or httpd
symbols.

Example:

 use ExtUtils::MakeMaker;

 use Apache2::Build ();

 WriteMakefile(
     'NAME'        => 'Apache2::Module',
     'VERSION'     => '0.01', 
     'INC'         => Apache2::Build->new->inc,
     'dynamic_lib' => {
         'OTHERLDFLAGS' => Apache2::Build->new->otherldflags,
     },
 );

=back


=head1 AUTHOR

Doug MacEachern

=cut
