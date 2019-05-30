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
package ModPerl::ParseSource;

use strict;
use Config ();
use Apache2::ParseSource ();

our @ISA = qw(Apache2::ParseSource);
our $VERSION = '0.01';

sub includes {
    my $self = shift;
    my $dirs = $self->SUPER::includes;
    return [
            '.', qw(xs src/modules/perl),
            @$dirs,
            "$Config::Config{archlibexp}/CORE",
           ];
}

sub include_dirs { '.' }

sub find_includes {
    my $self = shift;
    my $includes = $self->SUPER::find_includes;
    #filter/sort
    my @wanted  = grep { /mod_perl\.h/ } @$includes;
    push @wanted, grep { m:xs/modperl_xs_: } @$includes;
    push @wanted, grep { m:xs/[AM]: } @$includes;
    \@wanted;
}

my $prefixes = join '|', qw(modperl mpxs mp_xs);
my $prefix_re = qr{^($prefixes)_};
sub wanted_functions { $prefix_re }

sub write_functions_pm {
    my $self = shift;
    my $file = shift || 'FunctionTable.pm';
    my $name = shift || 'ModPerl::FunctionTable';
    $self->SUPER::write_functions_pm($file, $name);
}

for my $method (qw(get_constants get_structs write_structs_pm get_structs)) {
    no strict 'refs';
    *$method = sub { die __PACKAGE__ . "->$method not implemented" };
}

1;
__END__
