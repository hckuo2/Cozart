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
package ModPerl::BuildMM;

use strict;
use warnings;

use ExtUtils::MakeMaker ();
use Cwd ();
use File::Spec::Functions qw(catdir catfile splitdir);
use File::Basename;
use File::Find;

use Apache2::Build ();
use ModPerl::MM;
use constant WIN32 => Apache2::Build::WIN32;
use constant CYGWIN => Apache2::Build::CYGWIN;

our %PM; #add files to installation

# MM methods that this package overrides
no strict 'refs';
my $stash = \%{__PACKAGE__ . '::MY::'};
my @methods = grep *{$stash->{$_}}{CODE}, keys %$stash;
ModPerl::MM::override_eu_mm_mv_all_methods(@methods);
use strict 'refs';

my $apache_test_dir = catdir Cwd::getcwd(), "Apache-Test", "lib";

#to override MakeMaker MOD_INSTALL macro
sub mod_install {
    q{$(PERL) -I$(INST_LIB) -I$(PERL_LIB) \\}."\n" .
    qq{-I$apache_test_dir -MModPerl::BuildMM \\}."\n" .
    q{-e "ExtUtils::Install::install({@ARGV},'$(VERBINST)',0,'$(UNINST)');"}."\n";
}

my $build;

sub build_config {
    my $key = shift;
    $build ||= Apache2::Build->build_config;
    return $build unless $key;
    $build->{$key};
}

#the parent WriteMakefile moves MY:: methods into a different class
#so alias them each time WriteMakefile is called in a subdir

sub my_import {
    no strict 'refs';
    my $stash = \%{__PACKAGE__ . '::MY::'};
    for my $sym (keys %$stash) {
        next unless *{$stash->{$sym}}{CODE};
        my $name = "MY::$sym";
        undef &$name if defined &$name;
        *$name = *{$stash->{$sym}}{CODE};
    }
}

sub WriteMakefile {
    my %args = @_;

    $build ||= build_config();
    ModPerl::MM::my_import(__PACKAGE__);

    my $inc = $args{INC} || '';
    $inc = $args{INC} if $args{INC};
    $inc .= " " . $build->inc;
    if (my $glue_inc = $build->{MP_XS_GLUE_DIR}) {
        for (split /\s+/, $glue_inc) {
            $inc .= " -I$_";
        }
    }

    my $libs;
    my @libs = ();
    push @libs, $args{LIBS} if $args{LIBS};
    if (Apache2::Build::BUILD_APREXT) {
        # in order to decouple APR/APR::* from mod_perl.so,
        # link these modules against the static MP_APR_LIB lib,
        # rather than the mod_perl lib (which would demand mod_perl.so
        # be available). For other modules, use mod_perl.lib as
        # usual. This is done for APR in xs/APR/APR/Makefile.PL.
        my $name = $args{NAME};
        if ($name =~ /^APR::\w+$/) {
            # For cygwin compatibility, the order of the libs should be
            # <mod_perl libs> <apache libs>
            @libs = ($build->mp_apr_lib, $build->apache_libs);
        }
        else {
            @libs = ($build->modperl_libs, $build->apache_libs);
        }
    }
    else {
        @libs = ($build->modperl_libs, $build->apache_libs);
    }
    $libs = join ' ', @libs;

    my $ccflags;
    $ccflags = $args{CCFLAGS} if $args{CCFLAGS};
    $ccflags = " " . $build->perl_ccopts . $build->ap_ccopts;

    my $optimize;
    $optimize = $args{OPTIMIZE} if $args{OPTIMIZE};
    $optimize = " " . $build->perl_config('optimize');

    my $lddlflags;
    $lddlflags = $args{LDDLFLAGS} if $args{LDDLFLAGS};
    $lddlflags = " " . $build->perl_config('lddlflags');

    my %dynamic_lib;
    %dynamic_lib = %{ $args{dynamic_lib}||{} } if $args{dynamic_lib};
    $dynamic_lib{OTHERLDFLAGS} = $build->otherldflags;

    my @opts = (
        INC         => $inc,
        CCFLAGS     => $ccflags,
        OPTIMIZE    => $optimize,
        LDDLFLAGS   => $lddlflags,
        LIBS        => $libs,
        dynamic_lib => \%dynamic_lib,
    );

    my @typemaps;
    push @typemaps, $args{TYPEMAPS} if $args{TYPEMAPS};
    my $pwd = Cwd::fastcwd();
    for ('xs', $pwd, "$pwd/..") {
        my $typemap = $build->file_path("$_/typemap");
        if (-e $typemap) {
            push @typemaps, $typemap;
        }
    }
    push @opts, TYPEMAPS => \@typemaps if @typemaps;

    my $clean_files = (exists $args{clean} && exists $args{clean}{FILES}) ?
        $args{clean}{FILES} : '';
    $clean_files .= " glue_pods"; # cleanup the dependency target
    $args{clean}{FILES} = $clean_files;

    ExtUtils::MakeMaker::WriteMakefile(@opts, %args);
}

my %always_dynamic = map { $_, 1 }
  qw(ModPerl::Const Apache2::Const APR::Const APR APR::PerlIO);

sub ModPerl::BuildMM::MY::constants {
    my $self = shift;
    $build ||= build_config();

    #"discover" xs modules.  since there is no list hardwired
    #any module can be unpacked in the mod_perl-2.xx directory
    #and built static

    #this stunt also make it possible to leave .xs files where
    #they are, unlike 1.xx where *.xs live in src/modules/perl
    #and are copied to subdir/ if DYNAMIC=1

    if ($build->{MP_STATIC_EXTS}) {
        #skip .xs -> .so if we are linking static
        my $name = $self->{NAME};
        unless ($always_dynamic{$name}) {
            if (my ($xs) = keys %{ $self->{XS} }) {
                $self->{HAS_LINK_CODE} = 0;
                print "$name will be linked static\n";
                #propagate static xs module to src/modules/perl/Makefile
                $build->{XS}->{$name} =
                  join '/', Cwd::fastcwd(), $xs;
                $build->save;
            }
        }
    }

    $self->MM::constants;
}

sub ModPerl::BuildMM::MY::top_targets {
    my $self = shift;
    my $string = $self->MM::top_targets;

    return $string;
}

sub ModPerl::BuildMM::MY::postamble {
    my $self = shift;

    my $doc_root = catdir Cwd::getcwd(), "docs", "api";

    my @targets = ();

    # reasons for glueing pods to the respective .pm files:
    # - manpages will get installed over the mp1 manpages and vice
    #   versa. glueing pods avoids creation of manpages, but may be we
    #   could just tell make to skip manpages creation?
    # if pods are installed directly they need to be also redirected,
    # some into Apache2/ others (e.g. Apache2) not

    # add the code to glue the existing pods to the .pm files in blib.
    # create a dependency on pm_to_blib subdirs linkext targets to
    # allow 'make -j'
    require ExtUtils::MakeMaker;
    my $mm_ver = $ExtUtils::MakeMaker::VERSION;
    $mm_ver =~ s/_.*//; # handle dev versions like 6.30_01
    my $pm_to_blib = ($mm_ver >= 6.22 && $mm_ver <= 6.25)
        ? "pm_to_blib.ts"
        : "pm_to_blib";
    my @target = ("glue_pods: $pm_to_blib subdirs linkext");

    if (-d $doc_root) {
        my $build = build_config();

        # those living in modperl-2.0/lib are already nicely mapped
        my %pms = %{ $self->{PM} };

        my $cwd = Cwd::getcwd();
        my $blib_dir = catdir qw(blib lib);

        # those autogenerated under WrapXS/
        # those living under xs/
        # those living under ModPerl-Registry/lib/
        my @src = ('WrapXS', 'xs', catdir(qw(ModPerl-Registry lib)));

        for my $base (@src) {
            chdir $base;
            my @files = ();
            find({ no_chdir => 1,
                   wanted => sub { push @files, $_ if /.pm$/ },
                 }, ".");
            chdir $cwd;

            for (@files) {
                my $pm = catfile $base, $_;
                my $blib;
                if ($base =~ /^(xs|WrapXS)/) {
                    my @segm = splitdir $_;
                    splice @segm, -2, 1; # xs/APR/Const/Const.pm
                    splice @segm, -2, 1 if /APR.pm/; # odd case
                    $blib = catfile $blib_dir, @segm;
                }
                else {
                    $blib = catfile $blib_dir, $_;
                }
                $pms{$pm} = $blib;
            }
        }

        foreach my $pm (sort keys %pms) {
            my $blib = $pms{$pm};
            $pm   =~ s|/\./|/|g; # clean the path
            $blib =~ s|/\./|/|g; # clean the path
            my @segm = splitdir $blib;
            for my $i (1..2) {
                # try APR.pm and APR/Bucket.pm
                my $pod = catdir(@segm[-$i .. -1]);
                $pod =~ s/\.pm/\.pod/;
                my $podpath = catfile $doc_root, $pod;
                next unless -r $podpath;

                push @target,
                    '$(FULLPERL) -I$(INST_LIB) ' .
                    "-I$apache_test_dir -MModPerl::BuildMM " .
                    "-e ModPerl::BuildMM::glue_pod $pm $podpath $blib";

                # Win32 doesn't normally install man pages
                # and Cygwin doesn't allow '::' in file names
                next if WIN32 || CYGWIN;

                # manify while we're at it
                my (undef, $man, undef) = $blib =~ m!(blib/lib/)(.*)(\.pm)!;
                $man =~ s!/!::!g;

                push @target,
                    '$(NOECHO) $(POD2MAN_EXE) --section=3 ' .
                    "$podpath \$(INST_MAN3DIR)/$man.\$(MAN3EXT)"
            }
        }

        push @target, $self->{NOECHO} . '$(TOUCH) $@';
    }
    else {
        # we don't have the docs sub-cvs repository extracted, skip
        # the docs gluing
        push @target, $self->{NOECHO} . '$(NOOP)';
    }
    push @targets, join "\n\t", @target;

#    # next target: cleanup the dependency file
#    @target = ('glue_pods_clean:');
#    push @target, '$(RM_F) glue_pods';
#    push @targets, join "\n\t", @target;

    return join "\n\n", @targets, '';
}

sub glue_pod {

    die "expecting 3 arguments: pm, pod, dst" unless @ARGV == 3;
    my ($pm, $pod, $dst) = @ARGV;

    # it's possible that the .pm file is not existing
    # (e.g. ThreadMutex.pm is not created on unless
    # $apr_config->{HAS_THREADS})
    return unless -e $pm && -e $dst;

    # have we already glued the doc?
    exit 0 unless -s $pm == -s $dst;

    # ExtUtils::Install::pm_to_blib removes the 'w' perms, so we can't
    # just append the doc there
    my $orig_mode = (stat $dst)[2];
    my $rw_mode   = 0666;

    chmod $rw_mode, $dst      or die "Can't chmod $rw_mode $dst: $!";
    open my $pod_fh, "<$pod"  or die "Can't open $pod: $!";
    open my $dst_fh, ">>$dst" or die "Can't open $dst: $!";
    print $dst_fh "\n"; # must add one line separation
    print $dst_fh (<$pod_fh>);
    close $pod_fh;
    close $dst_fh;
    # restore the perms
    chmod $orig_mode, $dst    or die "Can't chmod $orig_mode $dst: $!";
}

sub ModPerl::BuildMM::MY::post_initialize {
    my $self = shift;
    $build ||= build_config();
    my $pm = $self->{PM};

    while (my ($k, $v) = each %PM) {
        if (-e $k) {
            $pm->{$k} = $v;
        }
    }

    # prefix typemap with Apache2/ so when installed in the
    # perl-lib-tree it won't be picked by non-mod_perl modules
    if (exists $pm->{'lib/typemap'} ) {
        $pm->{'lib/typemap'} = '$(INST_ARCHLIB)/auto/Apache2/typemap';
    }

    '';
}

my $apr_config;

sub ModPerl::BuildMM::MY::libscan {
    my ($self, $path) = @_;

    $apr_config ||= $build->get_apr_config();

    if ($path =~ m/(Thread|Global)(Mutex|RWLock)/) { 
        return unless $apr_config->{HAS_THREADS};
    }

    return '' if $path =~ /DummyVersions.pm/;

    return '' if $path =~ m/\.pl$/;
    return '' if $path =~ m/~$/;
    return '' if $path =~ /\B\.svn\b/;

    $path;
}

1;
