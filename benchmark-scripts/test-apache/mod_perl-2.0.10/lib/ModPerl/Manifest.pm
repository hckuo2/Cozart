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
package ModPerl::Manifest;

use strict;
use warnings FATAL => 'all';

use File::Basename;
use File::Find;
use Cwd ();
use Exporter ();

our @EXPORT_OK = qw(mkmanifest);

*import = \&Exporter::import;

#generate a MANIFEST based on CVS/Entries
#anything to be skipped goes after __DATA__ (MANIFEST.SKIP format)
#anything else to be added should go here:
my @add_files = qw{
    MANIFEST
    mod_perl.spec
    Apache-Test/META.yml
};

sub get_svn_files {
    my @files;

    my $cwd = Cwd::cwd();
    my @lines = `svn status -v` ;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /(?:\d+)\s+(?:\d+)\s+(?:\w+)\s+(.*)\s*/) {
            my $file = $1;
            if (-e $file && ! -d $file) {
                $file =~ s{\\}{/}g;
                push @files, $file;
            }
        }
    }

    # files to add which aren't under svn
    push @files, qw(lib/ModPerl/DummyVersions.pm lib/ModPerl/MethodLookup.pm);

    return @files;
}

sub mkmanifest {
    my @files = (@add_files, get_svn_files());

    my $matches = maniskip();
    open my $fh, '>', 'MANIFEST' or die "open MANIFEST: $!";

    for my $file (sort @files) {
        if ($matches->($file)) {
            warn "skipping $file\n";
            next;
        }

        print "$file\n";
        print $fh "$file\n";
    }

    close $fh;
}

#copied from ExtUtils::Manifest
#uses DATA instead of MANIFEST.SKIP
sub maniskip {
    my $matches = sub {0};
    my @skip;

    while (<DATA>){
        chomp;
        next if /^#/;
        next if /^\s*$/;
        push @skip, $_;
    }

    my $sub = "\$matches = "
        . "sub { my (\$arg)=\@_; return 1 if "
        . join (" || ",  (map {s!/!\\/!g; "\$arg =~ m/$_/o"} @skip), 0)
        . " }";

    eval $sub;

    $matches;
}

1;
__DATA__
patches/
#very few will have Chatbot::Eliza installed
eliza
# random failures
t/perl/ithreads.t
t/perl/ithreads2.t
t/response/TestPerl/ithreads.pm
t/response/TestPerl/ithreads_args.pm
t/response/TestPerl/ithreads_eval.pm
# broken/out-dated
t/perl/ithreads3.t
t/response/TestPerl/ithreads3.pm
# incomplete
t/apr-ext/perlio
# PAUSE breaks if a dist has more than one META.yml. the top-level
# META.yml already excludes Apache-Test from indexing
Apache-Test/META.yml
# exclude Apache-Test/MANIFEST since it confuses the mp2 build (e.g it
# wants Apache-Test/META.yml which we don't supply, see above)
Apache-Test/MANIFEST

# this is an internal to developers sub-project
Apache-Test/Apache-TestItSelf
