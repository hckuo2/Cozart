# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPRlib::uuid;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

my $dummy_uuid = 'd48889bb-d11d-b211-8567-ec81968c93c6';

require APR;
require APR::UUID;

#XXX: apr_generate_random_bytes may block forever on /dev/random
#    my $uuid = APR::UUID->new->format;

sub num_of_tests {
    return 3;
}

sub test {
    my $uuid = $dummy_uuid;

    ok $uuid;

    my $uuid_parsed = APR::UUID->parse($uuid);

    ok $uuid_parsed;

    ok $uuid eq $uuid_parsed->format;
}

1;
