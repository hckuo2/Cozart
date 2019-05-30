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

static MP_INLINE int mpxs_ap_run_sub_req(pTHX_ request_rec *r)
{
    /* need to flush main request output buffer if any
     * before running any subrequests, else we get subrequest
     * output before anything already written in the main request
     */

    if (r->main) {
        modperl_config_req_t *rcfg = modperl_config_req_get(r->main);
        if (rcfg->wbucket) {
            MP_RUN_CROAK(modperl_wbucket_flush(rcfg->wbucket, FALSE),
                         "Apache2::SubRequest::run");
        }
    }

    return ap_run_sub_req(r);
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
