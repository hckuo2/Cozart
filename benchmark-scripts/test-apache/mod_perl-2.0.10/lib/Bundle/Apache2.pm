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
package Bundle::Apache2;

$VERSION = '1.00';

1;

__END__

=head1 NAME

Bundle::Apache2 - Install Apache mod_perl2 and related modules



=head1 SYNOPSIS

C<perl -MCPAN -e 'install Bundle::Apache2'>



=head1 CONTENTS

Bundle::ApacheTest    - Needs for testing

CGI  3.11             - Used in testing (it's in core, but some vendors exclude it)

Chatbot::Eliza        - Used in testing

Compress::Zlib        - Used in testing

Devel::Symdump        - Symbol table browsing with Apache::Status

HTML::HeadParser      - Used in testing

IPC::Run3             - Used in testing

LWP                   - Used in testing




=head1 DESCRIPTION

This bundle contains modules used by Apache mod_perl2.

Asking CPAN.pm to install a bundle means to install the bundle itself
along with all the modules contained in the CONTENTS section
above. Modules that are up to date are not installed, of course.



=head1 AUTHOR

mod_perl 2 development team
