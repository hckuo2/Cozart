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
package ModPerl::BuildOptions;

use strict;
use warnings;

use Apache2::Build ();
use Apache::TestTrace;
use Config ();
my $param_qr = qr([\s=]+);

use constant VERBOSE => 1;
use constant UNKNOWN_FATAL => 2;

use File::Spec;

sub init {
    my ($class, $build) = @_;

    #@ARGV should override what's in .makepl_args.mod_perl2
    #but @ARGV might also override the default MP_OPTS_FILE
    #so snag that first
    parse($build, [grep { /^MP_OPTIONS_FILE/ } @ARGV]);
    parse_file($build);
    parse_argv($build);

    # if AP_PREFIX is used apxs and apr-config from the apache build
    # tree won't work, so it can't co-exist with APXS and APR_CONFIG
    # options
    if ($build->{MP_AP_PREFIX} and $build->{MP_APXS}) {
        error "You need to pass either MP_AP_PREFIX or MP_APXS, but not both";
        die "\n";
    }
    if ($build->{MP_AP_PREFIX} and $build->{MP_APR_CONFIG}) {
        error "You need to pass either MP_AP_PREFIX or MP_APR_CONFIG, " .
            "but not both";
        die "\n";
    }

    if ($build->{MP_DEBUG} and $build->{MP_USE_GTOP} and !$build->find_gtop) {
        error "Can't find libgtop, resetting MP_USE_GTOP=0";
        $build->{MP_USE_GTOP} = 0;
    }

    unless ($build->{MP_USE_DSO} or $build->{MP_USE_STATIC}) {
        # default to DSO
        $build->{MP_USE_DSO} = 1;
    }

    $build->{MP_GENERATE_XS} = 1 unless exists $build->{MP_GENERATE_XS};

    # define MP_COMPAT_1X unless explicitly told to disable it
    $build->{MP_COMPAT_1X} = 1
        unless exists $build->{MP_COMPAT_1X} && !$build->{MP_COMPAT_1X};

    # try to find apxs
    if (!$build->{MP_AP_PREFIX} && !$build->{MP_APXS}) {
        $build->find_apxs_util();

        # make a last ditch effort to find apxs in $ENV{PATH}
        if (!$build->{MP_APXS}) {
            my @paths = split(/$Config::Config{path_sep}/, $ENV{PATH});
            my $potential_apxs;
            while (!$potential_apxs) {
                last if scalar(@paths) == 0; # don't loop endlessly
                $potential_apxs = File::Spec->catfile(shift @paths, 'apxs');
                $potential_apxs .= '.bat' if Apache2::Build::WIN32();
                if (-e $potential_apxs && -x $potential_apxs) {
                    $build->{MP_APXS} = $potential_apxs;
                } else {
                    undef $potential_apxs;
                }
            }
        }
    }
}

sub parse {
    my ($build, $lines, $opts) = @_;

    $opts = VERBOSE|UNKNOWN_FATAL unless defined $opts;
    my $table = table();
    my @unknown;
    my $continue = "";

    my @data = ();
    for (@$lines) {
        chomp;
        s/^\s+//; s/\s+$//;
        next if /^\#/ || /^$/;
        last if /^__END__/;

        # more than one entry on the same line (but make sure to leave
        # -DMP_* alone)
        push @data, split /(?=\WMP_)/, $_;
    }

    for (@data) {
        #XXX: this "parser" should be more robust

        s/^\s+//; s/\s+$//;

        $_ = "$continue $_" if $continue;

        #example: +"MP_CCOPTS=-Werror" if $] >= 5.007
        if (s/^\+//) {
            $_ = eval $_;
        }

        if (/^MP_/) {
            my ($key, $val) = split $param_qr, $_, 2;
            $val ||= "" unless defined $val && $val eq '0';
            $continue = $val =~ s/\\$// ? $key : "";

            if (!$table->{$key} and $opts & UNKNOWN_FATAL) {
                my $usage = usage();
                die "Unknown Option: $key\nUsage:\n$usage\n";
            }

            if ($key eq 'MP_APXS') {
                $val = File::Spec->canonpath(File::Spec->rel2abs($val));
            }

            if ($key eq 'MP_AP_PREFIX') {
                $val = File::Spec->canonpath(File::Spec->rel2abs($val));

                if (Apache2::Build::WIN32()) {
                    # MP_AP_PREFIX may not contain spaces
                    require Win32;
                    $val = Win32::GetShortPathName($val);
                }

                if (!$val || !-d $val) {
                    error "MP_AP_PREFIX must point to a valid directory.";
                    die "\n";
                }
            }

            if ($table->{$key}->{append}){
                $build->{$key} = join " ", grep $_, $build->{$key}, $val;
            }
            else {
                $build->{$key} = $val;
            }

            print "   $key = $val\n" if $opts & VERBOSE;
        }
        else {
            push @unknown, $_;
        }
    }

    return \@unknown;
}

sub parse_file {
    my $build = shift;

    my $fh;
    my @dirs = qw(./ ../ ./. ../.);
    push @dirs, "$ENV{HOME}/." if exists $ENV{HOME};
    my @files = map { $_ . 'makepl_args.mod_perl2' } @dirs;
    unshift @files, $build->{MP_OPTIONS_FILE} if $build->{MP_OPTIONS_FILE};

    for my $file (@files) {
        if (open $fh, $file) {
            $build->{MP_OPTIONS_FILE} = $file;
            last;
        }
        $fh = undef;
    }

    return unless $fh;

    print "Reading Makefile.PL args from $build->{MP_OPTIONS_FILE}\n";
    my $unknowns = parse($build, [<$fh>]);
    push @ARGV, @$unknowns if $unknowns;

    close $fh;
}

sub parse_argv {
    my $build = shift;
    return unless @ARGV;

    my @args = @ARGV;
    @ARGV = ();

    print "Reading Makefile.PL args from \@ARGV\n";
    my $unknowns = parse($build, \@args);
    push @ARGV, @$unknowns if $unknowns;
}

sub usage {
    my $table = table();
    my @opts = map { "$_ - $table->{$_}->{val}" } sort keys %$table;
    join "\n", @opts;
}

sub parse_table {
    my ($fh) = @_;
    my %table;
    local $_;

    while (<$fh>) {
        chomp;
        s/^\s+//; s/\s+$//;
        next if /^\#/ || /^$/;
        last if /^__END__/;
        my ($key, $append, $val) = split /\s+/, $_, 3;
        $table{'MP_' . $key} = { append => $append, val => $val };
    }

    return \%table;
}

my $Table;

sub table {
    $Table ||= parse_table(\*DATA);
}

1;

# __DATA__ format:
# key        append     description
# where:
#     key:    is the option name
#     append: is whether we want to replace a default option (0)
#             or append the arg to the option (1)
#     desc:   description for this option

__DATA__
USE_GTOP       0    Link with libgtop and enable libgtop reporting
DEBUG          0    Turning on debugging (-g -lperld) and tracing
MAINTAINER     0    Maintainer mode: DEBUG=1 -DAP_DEBUG -Wall ...
CCOPTS         1    Add to compiler flags
TRACE          0    Turn on tracing
USE_DSO        0    Build mod_perl as a dso
USE_STATIC     0    Build mod_perl static
PROMPT_DEFAULT 0    Accept default value for all would-be prompts
OPTIONS_FILE   0    Read options from given file
STATIC_EXTS    0    Build Apache2::*.xs as static extensions
APXS           0    Path to apxs
AP_DESTDIR     0    Destination for Apache specific mod_perl bits
AP_PREFIX      0    Apache installation or source tree prefix
AP_CONFIGURE   0    Apache ./configure arguments
APR_CONFIG     0    Path to apr-config
APU_CONFIG     0    Path to apu-config
XS_GLUE_DIR    1    Directories containing extension glue
INCLUDE_DIR    1    Add directories to search for header files
GENERATE_XS    0    Generate XS code based on httpd version
LIBNAME        0    Name of the modperl dso library (default is  mod_perl)
COMPAT_1X      0    Compile-time mod_perl 1.0 backcompat (default is  on)
APR_LIB        0    Lib used to build APR::* on Win32 (default is aprext)
NO_THREADS     0    Build mod_perl without thread support with httpd >= 2.4
