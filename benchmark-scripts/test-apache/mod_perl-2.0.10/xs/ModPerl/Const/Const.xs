/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "mod_perl.h"
#include "modperl_const.h"

#ifndef WIN32
/* FIXME: To define extern perl_module to something so Const.so can be
 * loaded later. Without this code, loading Const.so fails with 
 * undefined_symbol: perl_module. (Windows does not need this since it
 * explicitly links against mod_perl.lib anyway.)
 */
module AP_MODULE_DECLARE_DATA perl_module = {
    STANDARD20_MODULE_STUFF,
    NULL, /* dir config creater */
    NULL,  /* dir merger --- default is to override */
    NULL, /* server config */
    NULL,  /* merge server config */
    NULL,              /* table of config file commands       */
    NULL,    /* register hooks */
};
#endif

MODULE = ModPerl::Const    PACKAGE = ModPerl::Const

PROTOTYPES: disable

BOOT:
#XXX:
#currently used just for {APR,Apache}/Const.{so,dll} to lookup
#XS_modperl_const_compile
#linking is fun.
newXS("ModPerl::Const::compile", XS_modperl_const_compile, __FILE__);

