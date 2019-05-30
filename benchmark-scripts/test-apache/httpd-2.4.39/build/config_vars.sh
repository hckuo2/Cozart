#! /bin/bash
# -*- sh -*-
#
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

# config_vars.sh is generated by configure, and is run by the "install-build"
# target to generate a version of config_vars.mk which is suitable to be
# installed.  Such a file cannot be generated at configure-time, since it
# requires the output of the *installed* ap*-config scripts.

# For a DESTDIR=... installation using the bundled copies of 
# apr/apr-util, the installed ap?-config scripts must be found 
# in the DESTDIR-relocated install tree.  For a DESTDIR=... 
# installation when using *external* copies of apr/apr-util,
# the absolute path must be used, not DESTDIR-relocated.

if test -f ${DESTDIR}/usr/bin/apr-1-config; then
   APR_CONFIG=${DESTDIR}/usr/bin/apr-1-config
   APU_CONFIG=${DESTDIR}/usr/bin/apu-1-config
else
   APR_CONFIG=/usr/bin/apr-1-config
   APU_CONFIG=/usr/bin/apu-1-config
fi

APR_LIBTOOL="`${APR_CONFIG} --apr-libtool`"
APR_INCLUDEDIR="`${APR_CONFIG} --includedir`"
test -n "/usr/bin/apu-1-config" && APU_INCLUDEDIR="`${APU_CONFIG} --includedir`"

installbuilddir="/home/hckuo2/test-apache/httpd-2.4.39/httpd-build/build"

exec sed "
/^[A-Z0-9_]*_LDADD/d
/MPM_LIB/d
/APACHECTL_ULIMIT/d
/[a-z]*_LTFLAGS/d
/^MPM_MODULES/d
/^ENABLED_MPM_MODULE/d
/^DSO_MODULES/d
/^MODULE_/d
/^PORT/d
/^SSLPORT/d
/^nonssl_/d
/^CORE_IMPLIB/d
/^rel_/d
/^abs_srcdir/d
/^BUILTIN_LIBS/d
/^[A-Z]*_SHARED_CMDS/d
/^shared_build/d
/^OS_DIR/d
/^AP_LIBS/d
/^OS_SPECIFIC_VARS/d
/^MPM_SUBDIRS/d
/^EXTRA_INCLUDES/{ 
  s, = , = -I\$(includedir) ,
  s, -I\$(top_srcdir)/[^ ]*,,g
  s, -I\$(top_builddir)/[^ ]*,,g
}
/^MKINSTALLDIRS/s,\$(abs_srcdir)/build,$installbuilddir,
/^INSTALL /s,\$(abs_srcdir)/build,$installbuilddir,
/^HTTPD_LDFLAGS/d
/^UTIL_LDFLAGS/d
/^APR_INCLUDEDIR.*$/s,.*,APR_INCLUDEDIR = ${APR_INCLUDEDIR},
/^APU_INCLUDEDIR.*$/s,.*,APU_INCLUDEDIR = ${APU_INCLUDEDIR},
/^LIBTOOL.*$/s,/[^ ]*/libtool \(.*\),${APR_LIBTOOL} --silent,
"
