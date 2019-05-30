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
package Apache2::porting;

use strict;
use warnings FATAL => 'all';

use Carp 'croak';

use ModPerl::MethodLookup ();
use Apache2::ServerUtil;

use Apache2::Const -compile => 'OK';

our $AUTOLOAD;

### methods ###
# handle:
# - removed and replaced methods
# - hinting the package names in which methods reside

my %avail_methods = map { $_ => 1 }
    (ModPerl::MethodLookup::avail_methods(),
     ModPerl::MethodLookup::avail_methods_compat());

# XXX: unfortunately it doesn't seem to be possible to install
# *UNIVERSAL::AUTOLOAD at the server startup, httpd segfaults,
# child_init seems to be the first stage where it works.
Apache2::ServerUtil->server->push_handlers(
    PerlChildInitHandler => \&porting_autoload);

sub porting_autoload {
    *UNIVERSAL::AUTOLOAD = sub {
        # This is a porting module, no compatibility layers are allowed in
        # this zone
        croak("Apache2::porting can't be used with Apache2::compat")
            if exists $ENV{"Apache2/compat.pm"};

        (my $method = $AUTOLOAD) =~ s/.*:://;

        # we skip DESTROY methods
        return if $method eq 'DESTROY';

        # we don't handle methods that we don't know about
        croak "Undefined subroutine $AUTOLOAD called"
            unless defined $method && exists $avail_methods{$method};

        my ($hint, @modules) =
            ModPerl::MethodLookup::lookup_method($method, @_);
        $hint ||= "Can't find method $AUTOLOAD";
        croak $hint;
    };

    return Apache2::Const::OK;
}

### packages ###
# handle:
# - removed and replaced packages

my %packages = (
     'Apache::Constants' => [qw(Apache2::Const)],
     'Apache::Table'     => [qw(APR::Table)],
     'Apache::File'      => [qw(Apache2::Response Apache2::RequestRec)],
     'Apache'            => [qw(ModPerl::Util Apache2::Module)],
);

BEGIN {
    sub my_require {
        my $package = $_[0];
        $package =~ s|/|::|g;
        $package =~ s|.pm$||;

        # this picks the original require (which could be overriden
        # elsewhere, so we don't lose that) because we haven't
        # overriden it yet
        return require $_[0] unless $packages{$package};

        my $msg = "mod_perl 2.0 API doesn't include package '$package'.";
        my @replacements = @{ $packages{$package}||[] };
        if (@replacements) {
            $msg .= " The package '$package' has moved to " .
                join " ", map qq/'$_'/, @replacements;
        }
        croak $msg;
    };

    *CORE::GLOBAL::require = sub (*) { my_require($_[0])};
}

1;
