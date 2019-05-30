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
apr_uri_t *mpxs_Apache2__RequestRec_parsed_uri(request_rec *r)
{
    modperl_uri_t *uri = modperl_uri_new(r->pool);

    uri->uri = r->parsed_uri;
    uri->path_info = r->path_info;

    return (apr_uri_t *)uri;
}

static MP_INLINE char *mpxs_ap_unescape_url(pTHX_ SV *url)
{
    int status;
    STRLEN n_a;

    (void)SvPV_force(url, n_a);

    if ((status = ap_unescape_url(SvPVX(url))) == OK) {
        SvCUR_set(url, strlen(SvPVX(url)));
    }

    return SvPVX(url);
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
