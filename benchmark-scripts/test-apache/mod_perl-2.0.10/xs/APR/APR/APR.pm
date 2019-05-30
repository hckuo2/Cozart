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
package APR;

use DynaLoader ();
our $VERSION = '0.009000';
our @ISA = qw(DynaLoader);

#dlopen("APR.so", RTDL_GLOBAL); so we only need to link libapr.a once
# XXX: see xs/ModPerl/Const/Const.pm for issues of using 0x01
use Config ();
use constant DL_GLOBAL =>
  ( $Config::Config{dlsrc} eq 'dl_dlopen.xs' && $^O ne 'openbsd' ) ? 0x01 : 0x0;
sub dl_load_flags { DL_GLOBAL }

unless (defined &APR::XSLoader::BOOTSTRAP) {
    __PACKAGE__->bootstrap($VERSION);
    *APR::XSLoader::BOOTSTRAP = sub () { 1 };
}

1;
__END__
