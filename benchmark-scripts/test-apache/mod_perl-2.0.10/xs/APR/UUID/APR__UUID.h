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

#define mpxs_apr_uuid_alloc() \
(apr_uuid_t *)safemalloc(sizeof(apr_uuid_t))

static MP_INLINE apr_uuid_t *mpxs_apr_uuid_get(pTHX_ SV *CLASS)
{
    apr_uuid_t *uuid = mpxs_apr_uuid_alloc();
    apr_uuid_get(uuid);
    return uuid;
}

static MP_INLINE void mp_apr_uuid_format(pTHX_ SV *sv, SV *obj)
{
    apr_uuid_t *uuid = mp_xs_sv2_uuid(obj);
    mpxs_sv_grow(sv, APR_UUID_FORMATTED_LENGTH);
    apr_uuid_format(SvPVX(sv), uuid);
    mpxs_sv_cur_set(sv, APR_UUID_FORMATTED_LENGTH);
}

static MP_INLINE apr_uuid_t *mpxs_apr_uuid_parse(pTHX_ SV *CLASS, char *buf)
{
    apr_uuid_t *uuid = mpxs_apr_uuid_alloc();
    apr_uuid_parse(uuid, buf);
    return uuid;
}

MP_STATIC XS(MPXS_apr_uuid_format)
{
    dXSARGS;

    mpxs_usage_items_1("uuid");

    mpxs_set_targ(mp_apr_uuid_format, ST(0));
}

#define apr_uuid_DESTROY(uuid) safefree(uuid)

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
