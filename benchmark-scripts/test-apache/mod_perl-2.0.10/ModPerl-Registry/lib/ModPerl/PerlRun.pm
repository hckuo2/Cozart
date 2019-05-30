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
package ModPerl::PerlRun;

use strict;
use warnings FATAL => 'all';

# we try to develop so we reload ourselves without die'ing on the warning
no warnings qw(redefine); # XXX, this should go away in production!

our $VERSION = '1.99';

use base qw(ModPerl::RegistryCooker);

sub handler : method {
    my $class = (@_ >= 2) ? shift : __PACKAGE__;
    my $r = shift;
    return $class->new($r)->default_handler();
}

my $parent = 'ModPerl::RegistryCooker';
# the following code:
# - specifies package's behavior different from default of $parent class
# - speeds things up by shortcutting @ISA search, so even if the
#   default is used we still use the alias
my %aliases = (
    new             => 'new',
    init            => 'init',
    default_handler => 'default_handler',
    run             => 'run',
    can_compile     => 'can_compile',
    make_namespace  => 'make_namespace',
    namespace_root  => 'namespace_root',
    namespace_from  => 'namespace_from_filename',
    is_cached       => 'FALSE',
    should_compile  => 'TRUE',
    flush_namespace => 'flush_namespace_normal',
    cache_table     => 'cache_table_common',
    cache_it        => 'NOP',
    read_script     => 'read_script',
    shebang_to_perl => 'shebang_to_perl',
    get_script_name => 'get_script_name',
    chdir_file      => 'NOP',
    get_mark_line   => 'get_mark_line',
    compile         => 'compile',
    error_check     => 'error_check',
    should_reset_inc_hash => 'TRUE',
    strip_end_data_segment             => 'strip_end_data_segment',
    convert_script_to_compiled_handler => 'convert_script_to_compiled_handler',
);

# in this module, all the methods are inherited from the same parent
# class, so we fixup aliases instead of using the source package in
# first place.
$aliases{$_} = $parent . "::" . $aliases{$_} for keys %aliases;

__PACKAGE__->install_aliases(\%aliases);





1;
__END__

