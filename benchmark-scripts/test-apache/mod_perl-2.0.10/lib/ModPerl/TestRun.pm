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
package ModPerl::TestRun;

use strict;
use warnings FATAL => 'all';

use base qw(Apache::TestRunPerl);

use Apache2::Build;

# some mp2 tests require more than one server instance to be available
# without which the server may hang, waiting for the single server
# become available
use constant MIN_CLIENTS => 2;

sub new_test_config {
    my $self = shift;

    # default timeout in secs (threaded mpms are extremely slow to
    # startup, due to a slow perl_clone operation)
    $self->{conf_opts}->{startup_timeout} ||=
        $ENV{APACHE_TEST_STARTUP_TIMEOUT} ||
        Apache2::Build->build_config->mpm_is_threaded() ? 300 : 120;

    $self->{conf_opts}->{minclients} ||= MIN_CLIENTS;

    ModPerl::TestConfig->new($self->{conf_opts});
}

sub bug_report {
    my $self = shift;

    print <<EOI;
+--------------------------------------------------------+
| Please file a bug report: http://perl.apache.org/bugs/ |
+--------------------------------------------------------+
EOI
}

package ModPerl::TestConfig;

use base qw(Apache::TestConfig);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my $config = Apache2::Build->build_config;
    $self->{conf_opts}->{httpd} ||= $config->{httpd};
    return $self;
}

# - don't inherit LoadModule perl_module from the apache httpd.conf
# - loaded fastcgi crashes some mp2 tests
my @skip = ('mod_perl.c', qr/mod_fastcgi.*?\.c$/);

Apache::TestConfig::autoconfig_skip_module_add(@skip);

1;

