#!/usr/bin/perl -w
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

# perlbloat.pl 'some perlcode' 'more perl code'
# perlbloat.pl Foo/Bar.pm Bar/Tar.pm
# perlbloat.pl Foo::Bar Bar::Tar

no warnings;

use GTop ();

my $gtop = GTop->new;

my $total = 0;
for (@ARGV) {

    my $code = $_;
    file2package($_) if /\S+\.pm$/;

    my $before = $gtop->proc_mem($$)->size;

    if (eval "require $_" ) {
        eval {
            $_->import;
        };
    }
    else {
        eval $_;
        die $@ if $@;
    }

    my $after = $gtop->proc_mem($$)->size;
    printf "%-30s added %s\n", $_, GTop::size_string($after - $before);
    $total += $after - $before;
}

print "-" x 46, "\n";
printf "Total added %30s\n", GTop::size_string($total);

sub file2package {
    $_[0] =~ s|/|::|g;
    $_[0] =~ s|\.pm$||;
}

