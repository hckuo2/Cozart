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
package ModPerl::Config;

use strict;

use Apache2::Build ();
use Apache::TestConfig ();
use File::Spec ();

use constant WIN32 => Apache2::Build::WIN32;

sub as_string {
    my $build = Apache2::Build->build_config;

    my $cfg = '';

    $cfg .= "*** mod_perl version $mod_perl::VERSION\n\n";;

    my $file = File::Spec->rel2abs($INC{'Apache2/BuildConfig.pm'});
    $cfg .= "*** using $file\n\n";

    # the widest key length
    my $max_len = 0;
    for (map {length} grep /^MP_/, keys %$build) {
        $max_len = $_ if $_ > $max_len;
    }

    # mod_perl opts
    $cfg .= "*** Makefile.PL options:\n";
    $cfg .= join '',
        map {sprintf "  %-${max_len}s => %s\n", $_, $build->{$_}}
            grep /^MP_/, sort keys %$build;

    my $command = '';

    # httpd opts
    my $test_config = Apache::TestConfig->new({thaw=>1});

    if (my $httpd = $test_config->{vars}->{httpd}) {
        $command = "$httpd -V";
        $cfg .= "\n\n*** $command\n";
        $cfg .= qx{$command};

        $cfg .= Apache::TestConfig::ldd_as_string($httpd);
    }
    else {
        $cfg .= "\n\n*** The httpd binary was not found\n";
    }

    # apr
    $cfg .= "\n\n*** (apr|apu)-config linking info\n\n";
    my @apru_link_flags = $build->apru_link_flags;
    if (@apru_link_flags) {
        my $libs = join "\n", @apru_link_flags;
        $cfg .= "$libs\n\n";
    }
    else {
        $cfg .= "(apr|apu)-config scripts were not found\n\n";
    }

    # perl opts
    my $perl = $build->{MODPERL_PERLPATH};
    $command = "$perl -V";
    $cfg .= "\n\n*** $command\n";
    $cfg .= qx{$command};

    return $cfg;

}

1;
__END__

=pod

=head1 NAME

ModPerl::Config - Functions to retrieve mod_perl specific env information.

=head1 DESCRIPTION

=cut

