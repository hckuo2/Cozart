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

static MP_INLINE SV *mpxs_Apache2__MPM_query(pTHX_ SV *self, int query_code)
{
    int mpm_query_info;

    apr_status_t retval = ap_mpm_query(query_code, &mpm_query_info);

    if (retval == APR_SUCCESS) {
        return newSViv(mpm_query_info);
    }

    return &PL_sv_undef;
}

static void mpxs_Apache2__MPM_BOOT(pTHX)
{
    /* implement Apache2::MPM->show and Apache2::MPM->is_threaded
     * as constant subroutines, since this information will never
     * change during an interpreter's lifetime */

    int mpm_query_info;

    apr_status_t retval = ap_mpm_query(AP_MPMQ_IS_THREADED, &mpm_query_info);

    if (retval == APR_SUCCESS) {
        MP_TRACE_g(MP_FUNC, "defined Apache2::MPM->is_threaded() as %i",
                   mpm_query_info);

        newCONSTSUB(PL_defstash, "Apache2::MPM::is_threaded",
                    newSViv(mpm_query_info));
    }
    else {
        /* assign false (0) to sub if ap_mpm_query didn't succeed */
        MP_TRACE_g(MP_FUNC, "defined Apache2::MPM->is_threaded() as 0");

        newCONSTSUB(PL_defstash, "Apache2::MPM::is_threaded",
                    newSViv(0));
    }

    MP_TRACE_g(MP_FUNC, "defined Apache2::MPM->show() as %s",
               ap_show_mpm());

    newCONSTSUB(PL_defstash, "Apache2::MPM::show",
                newSVpv(ap_show_mpm(), 0));
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
