# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package perlrun_decl;

use warnings;
use strict;

use base qw(Exporter);
our @EXPORT = qw(decl_proto);

# this BEGIN block is called only once, since this module doesn't get
# removed from %INC after it was loaded
BEGIN {
    # use an external package which will persist across requests
    $MyData::blocks{perlrun_decl}++;
}

sub decl_proto ($;$) { shift }

# this END block won't be executed until the server shutdown
END {
    $MyData::blocks{perlrun_decl}--;
}

1;
