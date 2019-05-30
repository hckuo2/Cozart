#!/usr/bin/perl -w
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

#get an idea of how much space the XS interface will eat
#build/source_scan.pl must be run first
#see pod/modperl_sizeof.pod

use strict;
use Apache2::FunctionTable ();
use Apache2::StructureTable ();

use constant sizeofCV => 254;

my $size = 0;
my $subs = 0;

for my $entry (@$Apache2::FunctionTable) {
    $size += sizeofCV + ((length($entry->{name}) + 1) * 2);
    $subs++;
}

for my $entry (@$Apache2::StructureTable) {
    my $elts = $entry->{elts} || [];
    next unless @$elts;

    for my $e (@$elts) {
        $size += sizeofCV + ((length($e->{name}) + 1) * 2);
        $subs++;
    }
}

print "$subs subs, $size estimated bytes\n";
