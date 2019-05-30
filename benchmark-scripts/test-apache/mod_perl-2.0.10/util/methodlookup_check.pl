#!/usr/bin/perl
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

# this script checks whether all XS methods are known to ModPerl::MethodLookup

use strict;
use warnings;

use lib "lib";

use ModPerl::MethodLookup;

# methods/classes ModPerl::MethodLookup knows about
my %known = ();
for (ModPerl::MethodLookup::avail_methods()) {
    my ($modules_hint, @modules) = ModPerl::MethodLookup::lookup_method($_);
    $known{$_} = { map {$_ => 1} @modules};
}

# real XS methods
my %real = ();
my $in = qx{grep -Ir newXS WrapXS};
while ($in =~ m{WrapXS/(\w+)/(\w+)/.*?newXS\("(?:.+)::(.+)"}g) {
    $real{$3}{"$1\::$2"}++;
}

# now check what's missing
my @miss = ();
for my $method (sort keys %real) {
    for my $module (sort keys %{ $real{$method} }) {
        #printf "%-25s %s\n", $method, $module unless $known{$method}{$module};
        push @miss, sprintf "%-25s %s\n", $module, $method unless $known{$method}{$module};
    }
}

print @miss ? sort(@miss) : "All methods are known by ModPerl::MethodLookup\n";
