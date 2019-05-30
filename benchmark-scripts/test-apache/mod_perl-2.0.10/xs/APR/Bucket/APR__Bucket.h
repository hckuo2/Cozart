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

#include "modperl_bucket.h"

#define mpxs_APR__Bucket_delete  apr_bucket_delete
#define mpxs_APR__Bucket_destroy apr_bucket_destroy

static apr_bucket *mpxs_APR__Bucket_new(pTHX_  SV *classname, apr_bucket_alloc_t *list,
                                        SV *sv, apr_off_t offset, apr_size_t len)
{

    apr_size_t full_len;

    if (sv == (SV *)NULL) {
        sv = newSV(0);
        (void)SvUPGRADE(sv, SVt_PV);
    }

    (void)SvPV(sv, full_len);

    if (len) {
        if (len > full_len - offset) {
            Perl_croak(aTHX_ "APR::Bucket::new: the length argument can't be"
                       " bigger than the total buffer length minus offset");
        }
    }
    else {
        len = full_len - offset;
    }

    return modperl_bucket_sv_create(aTHX_ list, sv, offset, len);
}

static MP_INLINE
apr_size_t mpxs_APR__Bucket_read(pTHX_
                                 apr_bucket *bucket,
                                 SV *buffer,
                                 apr_read_type_e block)
{
    apr_size_t len;
    const char *str;
    apr_status_t rc = apr_bucket_read(bucket, &str, &len, block);

    if (!(rc == APR_SUCCESS || rc == APR_EOF)) {
        modperl_croak(aTHX_ rc, "APR::Bucket::read");
    }

    if (len) {
        sv_setpvn(buffer, str, len);
    }
    else {
        sv_setpvn(buffer, "", 0);
    }

    /* must run any set magic */
    SvSETMAGIC(buffer);

    SvTAINTED_on(buffer);

    return len;
}

static MP_INLINE int mpxs_APR__Bucket_is_eos(apr_bucket *bucket)
{
    return APR_BUCKET_IS_EOS(bucket);
}

static MP_INLINE int mpxs_APR__Bucket_is_flush(apr_bucket *bucket)
{
    return APR_BUCKET_IS_FLUSH(bucket);
}

static MP_INLINE void mpxs_APR__Bucket_insert_before(apr_bucket *a,
                                                     apr_bucket *b)
{
    APR_BUCKET_INSERT_BEFORE(a, b);
}

static MP_INLINE void mpxs_APR__Bucket_insert_after(apr_bucket *a,
                                                    apr_bucket *b)
{
    APR_BUCKET_INSERT_AFTER(a, b);
}

static MP_INLINE void mpxs_APR__Bucket_remove(apr_bucket *bucket)
{
    APR_BUCKET_REMOVE(bucket);
}

static MP_INLINE
apr_status_t mpxs_APR__Bucket_setaside(pTHX_ SV *b_sv, SV *p_sv)
{
    apr_pool_t *p = mp_xs_sv2_APR__Pool(p_sv);
    apr_bucket *b = mp_xs_sv2_APR__Bucket(b_sv);
    apr_status_t rc = apr_bucket_setaside(b, p);

    /* if users don't bother to check the success, do it on their
     * behalf */
    if (GIMME_V == G_VOID && rc != APR_SUCCESS) {
        modperl_croak(aTHX_ rc, "APR::Bucket::setaside");
    }

    /* No need to call mpxs_add_pool_magic(b_sv, p_sv); since
     * pool_bucket_cleanup is called by apr_bucket_pool_make (called
     * by modperl_bucket_sv_setaside) if the pool goes out of scope,
     * copying the data to the heap.
     */

    return rc;
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
