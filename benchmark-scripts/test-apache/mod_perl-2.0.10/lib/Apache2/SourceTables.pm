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
package Apache2::SourceTables;

use Apache2::StructureTable ();
use Apache2::FunctionTable ();

#build hash versions of the tables
%Apache2::StructureTable =
  map { $_->{type}, $_->{elts} } @$Apache2::StructureTable;

%Apache2::FunctionTable =
  map { $_->{name}, {elts => $_->{elts},
                     return_type => $_->{return_type} } }
          @$Apache2::FunctionTable;

1;
__END__
