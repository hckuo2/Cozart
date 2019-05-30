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

#ifdef USE_ITHREADS
#define mpxs_ModPerl__Util_current_perl_id() \
    Perl_newSVpvf(aTHX_ "0x%lx", (unsigned long)aTHX)
#else
#define mpxs_ModPerl__Util_current_perl_id() \
    Perl_newSVpvf(aTHX_ "0x%lx", (unsigned long)0)
#endif

static MP_INLINE void mpxs_ModPerl__Util_untaint(pTHX_ I32 items,
                                                 SV **MARK, SV **SP)
{
    if (!PL_tainting) {
        return;
    }
    while (MARK <= SP) {
        sv_untaint(*MARK++);
    }
}

#define mpxs_ModPerl__Util_current_callback \
    modperl_callback_current_callback_get

#define mpxs_ModPerl__Util_unload_package_xs(pkg) \
    modperl_package_unload(aTHX_ pkg)

/* ModPerl::Util::exit lives in mod_perl.so, see modperl_perl.c */

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
