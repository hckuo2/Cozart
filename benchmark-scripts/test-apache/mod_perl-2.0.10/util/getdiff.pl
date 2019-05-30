#!/usr/bin/perl -w
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

# this script creates a diff against SVN
# and against /dev/null for all files in ARGV
# and prints it to STDOUT
#
# e.g.
# getdiff.pl t/modules/newtest t/response/TestModules/NewTest.pm \
# > newtest.patch
#
# the generated patch can be applied with
# patch -p0 < newtest.patch

# cvs diff
my $o = `svn diff`;

for (@ARGV) {
    $o .= "\n";
    $o .= `diff -u /dev/null $_`
}

print $o;

