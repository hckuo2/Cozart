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

static MP_INLINE
SV *mpxs_APR__Finfo_stat(pTHX_ const char *fname, apr_int32_t wanted,
                         SV *p_sv)
{
    apr_pool_t *p = mp_xs_sv2_APR__Pool(p_sv);
    apr_finfo_t *finfo = (apr_finfo_t *)apr_pcalloc(p, sizeof(apr_finfo_t));
    SV *finfo_sv;

    MP_RUN_CROAK(apr_stat(finfo, fname, wanted, p),
                 "APR::Finfo::stat");

    finfo_sv = sv_setref_pv(newSV(0), "APR::Finfo", (void*)finfo);
    mpxs_add_pool_magic(finfo_sv, p_sv);

    return finfo_sv;
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
