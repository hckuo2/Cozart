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

/* XXX: this should probably named $r->cgi_header_parse
 * and send_cgi_header an alias in Apache2::compat
 */
#define mpxs_Apache2__RequestRec_send_cgi_header(r, sv) \
{ \
    MP_dRCFG; \
    STRLEN len; \
    const char *bodytext; \
    MP_CGI_HEADER_PARSER_OFF(rcfg); \
    SvPV_force(sv, len);            \
    modperl_cgi_header_parse(r, SvPVX(sv), (apr_size_t*)&len, &bodytext); \
    if (len) {\
        MP_CHECK_WBUCKET_INIT("$r->send_cgi_header"); \
        modperl_wbucket_write(aTHX_ rcfg->wbucket, bodytext, &len); \
    } \
}

static MP_INLINE void
mpxs_Apache2__RequestRec_set_last_modified(request_rec *r, apr_time_t mtime)
{
    if (mtime) {
        ap_update_mtime(r, mtime);
    }
    ap_set_last_modified(r);
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
