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

typedef void (*mpxs_special_list_do_t)(pTHX_ modperl_modglobal_key_t *,
                                       const char *, I32);

static int mpxs_special_list_do(pTHX_ const char *name,
                                SV *package,
                                mpxs_special_list_do_t func)
{
    STRLEN packlen;
    char *packname;
    modperl_modglobal_key_t *gkey = modperl_modglobal_lookup(aTHX_ name);

    if (!gkey) {
        return FALSE;
    }

    packname = SvPV(package, packlen);

    func(aTHX_ gkey, packname, packlen);

    return TRUE;
}

static
MP_INLINE int mpxs_ModPerl__Global_special_list_call(pTHX_ const char *name,
                                                     SV *package)
{
    return mpxs_special_list_do(aTHX_ name, package,
                                modperl_perl_global_avcv_call);
}

static
MP_INLINE int mpxs_ModPerl__Global_special_list_clear(pTHX_ const char *name,
                                                      SV *package)
{
    return mpxs_special_list_do(aTHX_ name, package,
                                modperl_perl_global_avcv_clear);
}

static
MP_INLINE int mpxs_ModPerl__Global_special_list_register(pTHX_
                                                         const char *name,
                                                         SV *package)
{
    return mpxs_special_list_do(aTHX_ name, package,
                                modperl_perl_global_avcv_register);
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
