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
package mod_perl2;

use 5.006;
use strict;

BEGIN {
    our $VERSION = "2.000010";
    our $VERSION_TRIPLET;

    if ($VERSION =~ /(\d+)\.(\d\d\d)(\d+)/) {
        my $v1 = $1;
        my $v2 = int $2;
        my $v3 = int($3 . "0" x (3 - length $3));
        $VERSION_TRIPLET = "$v1.$v2.$v3";
    }
    else {
        die "bad version: $VERSION";
    }

    # for example this gives us:
    # $VERSION        : "2.000020"
    # int $VERSION    : 2.00002
    # $VERSION_TRIPLET: 2.0.20

    # easy to parse request time  API version - use
    # $mod_perl2::VERSION for more granularity
    our $API_VERSION = 2;
}

# this stuff is here to assist back compat
# basically, if you
#  PerlModule mod_perl2
# or take similar steps to load mod_perl2 at
# startup you are protected against loading mod_perl.pm
# (either 1.0 or 1.99) at a later time by accident.
$mod_perl::VERSION = $mod_perl2::VERSION;
$INC{"mod_perl.pm"} = __FILE__;

1;
__END__

=head1 NAME

mod_perl - Embed a Perl interpreter in the Apache/2.x HTTP server

