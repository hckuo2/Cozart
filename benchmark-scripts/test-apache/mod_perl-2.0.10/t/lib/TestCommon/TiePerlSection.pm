# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCommon::TiePerlSection;

use strict;
use warnings FATAL => 'all';

# the following is needed for the tied %Location test in <Perl>
# sections. Unfortunately it can't be defined in the section itself
# due to the bug in perl:
# http://rt.perl.org:80/rt3/Ticket/Display.html?id=29018

use Tie::Hash;
our @ISA = qw(Tie::StdHash);
sub FETCH {
    my ($hash, $key) = @_;
    if ($key eq '/tied') {
        return 'TIED';
    }
    return $hash->{$key};
}

1;
