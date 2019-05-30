# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
#calculate structure sizes listed in pod/modperl_sizeof.pod via sizeof()

use strict;

use ExtUtils::Embed;
use Config;

my $file = shift || 'pod/modperl_sizeof.pod';

open my $pod, $file or die "open $file: $!";

FINDSTRUCT: {
    while (<$pod>) {
        next unless /^\s*(\w+)\s*=\s*\{/;
        my $name = $1;
        my $size = sizeof($name, $pod);
        print "sizeof $name => $size\n";
        redo FINDSTRUCT;
    }
}

sub sizeof {
    my($struct, $h) = @_;

    my @elts;

    while (<$h>) {
        last if /^\s*\}\;$/;
        next unless m:(\w+).*?//\s*(.*):;
        push @elts, "sizeof($2) /* $1 */";
    }

    my $name = "perl_sizeof_$struct";
    my $tmpfile = "$name.c";
    open my $fh, '>', $tmpfile or die "open $tmpfile: $!";

    local $" = " + \n";

    print $fh <<EOF;
#include <stdio.h>
#define PERLIO_NOT_STDIO 0
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#undef fprintf
int main(void) {
    int size = @elts;
    fprintf(stdout, "%d", size);
    return 1;
}
EOF

    my $opts = ccopts();
    system "$Config{cc} -o $name $tmpfile $opts";

    my $size = `$name`;

    unlink $name, $tmpfile;

    return $size;
}
