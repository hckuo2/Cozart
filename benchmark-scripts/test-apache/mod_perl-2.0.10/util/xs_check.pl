# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use lib qw(Apache-Test/lib lib xs/tables/current);

use strict;
use warnings qw(FATAL all);

use ModPerl::TypeMap ();
use ModPerl::FunctionMap ();
use ModPerl::StructureMap ();
use ModPerl::WrapXS ();
use ModPerl::MapUtil qw(disabled_reason);

my %check = (
    types      => ModPerl::TypeMap->new,
    functions  => ModPerl::FunctionMap->new,
    structures => ModPerl::StructureMap->new,
);

my %missing;
while (my($things, $obj) = each %check) {
    $missing{$things} = $obj->check;
    if (my $missing = $missing{$things}) {
        my $n = @$missing;
        print "$n $things are not mapped:\n";
        print " $_\n" for sort @$missing;
    }
    else {
        print "all $things are mapped\n";
    }
}

my %check_exists = (
    functions => $check{functions},
    structure_members => $check{structures},
    types => $check{types},
);

while (my($things, $obj) = each %check_exists) {
    if (my $missing = $obj->check_exists) {
        my $n = @$missing;
        print "$n mapped $things do not exist:\n";
        print " $_\n" for sort @$missing;
    }
    else {
        print "all mapped $things exist\n";
    }
}

my %unmapped = map { $_,1 } @{ $missing{functions} } if $missing{functions};
my $typemap = $check{types};
my $function_map = $check{functions};
my @missing;

for my $entry (@$Apache2::FunctionTable) {
    my $func;
    my $name = $entry->{name};
    next if $unmapped{$name};
    next unless $function_map->{map}->{$name};
    next if $func = $typemap->map_function($entry);
    push @missing, $name;
}

if (@missing) {
    my $n = @missing;
    print "unable to glue $n mapped functions:\n";
    print " $_\n" for sort @missing;
}
else {
    print "all mapped functions are glued\n";
}

my $stats = ModPerl::WrapXS->new->stats;
my($total_modules, $total_xsubs);

while (my($module, $n) = each %$stats) {
    $total_modules++;
    $total_xsubs += $n;
}

print "$total_modules total modules, ",
          "$total_xsubs total xsubs\n";

while (my($module, $n) = each %$stats) {
    print "$module: $n\n";
}

for (qw(functions structure_members)) {
    my $disabled = $check_exists{$_}->disabled;
    my $total = 0;
    for my $names (values %$disabled) {
        $total += @$names;
    }
    print "$total $_ are not wrapped:\n";
    while (my($r, $names) = each %$disabled) {
        printf "%4d are %s\n", scalar @$names, disabled_reason($r);
    }
}

if (@ARGV) {
    my $key = '!';
    for (qw(functions structure_members)) {
        my $disabled = $check_exists{$_}->disabled;
        my $names = $disabled->{$key};
        printf "%s $_:\n", disabled_reason($key);
        for my $name (sort @$names) {
            print "   $name\n";
        }
    }
}
