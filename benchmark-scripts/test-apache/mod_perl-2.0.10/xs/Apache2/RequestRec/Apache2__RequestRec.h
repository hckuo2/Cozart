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
const char *mpxs_Apache2__RequestRec_content_type(pTHX_ request_rec *r,
                                                 SV *type)
{
    const char *retval = r->content_type;

    if (type) {
        MP_dRCFG;
        STRLEN len;
        const char *val = SvPV(type, len);
        ap_set_content_type(r, apr_pmemdup(r->pool, val, len+1));
        MP_CGI_HEADER_PARSER_OFF(rcfg);
    }

    return retval;
}

static MP_INLINE
SV *mpxs_Apache2__RequestRec_content_languages(pTHX_ request_rec *r,
                                              SV *languages)
{
    SV *retval = modperl_apr_array_header2avrv(aTHX_
                                               r->content_languages);
    if (languages) {
        r->content_languages = modperl_avrv2apr_array_header(aTHX_
                                                             r->pool,
                                                             languages);
    }
    return retval;
}

static MP_INLINE
int mpxs_Apache2__RequestRec_proxyreq(pTHX_ request_rec *r, SV *val)
{
    int retval = r->proxyreq;

    if (!val && !r->proxyreq &&
        r->parsed_uri.scheme &&
        !(r->parsed_uri.hostname &&
          strEQ(r->parsed_uri.scheme, ap_http_scheme(r)) &&
          ap_matches_request_vhost(r, r->parsed_uri.hostname,
                                   r->parsed_uri.port_str ?
                                   r->parsed_uri.port :
                                   ap_default_port(r))))
    {
        retval = r->proxyreq = PROXYREQ_PROXY;
        r->uri = r->unparsed_uri;
        /* else mod_proxy will segfault */
        r->filename = apr_pstrcat(r->pool, "modperl-proxy:", r->uri, NULL);
    }

    if (val) {
        r->proxyreq = SvIV(val);
    }

    return retval;
}

static MP_INLINE
SV *mpxs_Apache2__RequestRec_subprocess_env(pTHX_ request_rec *r,
                                           char *key, SV *val)
{
    /* if called in a void context with no arguments, just
     * populate %ENV and stop.
     */
    if (key == NULL && GIMME_V == G_VOID) {
        modperl_env_request_populate(aTHX_ r);
        return &PL_sv_undef;
    }

    return modperl_table_get_set(aTHX_ r->subprocess_env,
                                 key, val, TRUE);
}

static MP_INLINE
apr_finfo_t *mpxs_Apache2__RequestRec_finfo(pTHX_ request_rec *r,
                                           apr_finfo_t *finfo)
{
    if (finfo) {
        r->finfo = *finfo;
    }

    return &r->finfo;
}

static MP_INLINE
const char *mpxs_Apache2__RequestRec_handler(pTHX_  I32 items,
                                            SV **MARK, SV **SP)
{
    const char *RETVAL;
    request_rec *r;
    mpxs_usage_va_1(r, "$r->handler([$handler])");

    RETVAL = (const char *)r->handler;

    if (items == 2) {
        if (SvPOK(*MARK)) {
            char *new_handler = SvPVX(*MARK);
            /* once inside a response phase, one should not try to
             * switch response handler types, since they won't take
             * any affect */
            if (strEQ(modperl_callback_current_callback_get(),
                      "PerlResponseHandler")) {

                switch (*new_handler) {
                  case 'm':
                    if (strEQ(new_handler, "modperl") &&
                        strEQ(RETVAL, "perl-script")) {
                        Perl_croak(aTHX_ "Can't switch from 'perl-script' "
                                   "to 'modperl' response handler");
                    }
                    break;
                  case 'p':
                    if (strEQ(new_handler, "perl-script") &&
                        strEQ(RETVAL, "modperl")) {
                        Perl_croak(aTHX_ "Can't switch from 'modperl' "
                                   "to 'perl-script' response handler");
                    }
                    break;
                }
            }

            r->handler = (const char *)apr_pstrmemdup(r->pool, new_handler,
                                                      SvLEN(*MARK));
        }
        else {
            Perl_croak(aTHX_ "the new_handler argument must be a string");
        }
    }

    return RETVAL;
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
