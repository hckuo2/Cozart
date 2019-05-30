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

#define apr_thread_rwlock_DESTROY apr_thread_rwlock_destroy

static MP_INLINE
SV *mpxs_apr_thread_rwlock_create(pTHX_ SV *classname, SV *p_sv)
{
    apr_pool_t *p = mp_xs_sv2_APR__Pool(p_sv);
    apr_thread_rwlock_t *rwlock = NULL;
    SV *rwlock_sv;
    (void)apr_thread_rwlock_create(&rwlock, p);
    rwlock_sv = sv_setref_pv(newSV(0), "APR::ThreadRWLock", (void*)rwlock);
    mpxs_add_pool_magic(rwlock_sv, p_sv);
    return rwlock_sv;
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
