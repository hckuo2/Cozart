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
char *mpxs_apr_uri_unparse(pTHX_
                           apr_uri_t *uptr,
                           unsigned flags)
{

    /* apr =< 0.9.2-dev segfaults if hostname is set, but scheme is not.
     * apr >= 0.9.2 simply uses "", which will force the user to set scheme
     * since apr_uri_unparse is protocol-agnostic, it doesn't use
     * 'http' as the default fallback anymore. so we use the same solution
     */
#if APR_MAJOR_VERSION == 0 && APR_MINOR_VERSION == 9 && \
    (APR_PATCH_VERSION < 2 || APR_PATCH_VERSION == 2 && defined APR_IS_DEV_VERSION)
    if (uptr->hostname && !uptr->scheme) {
        uptr->scheme = "";
    }
#endif

    return apr_uri_unparse(((modperl_uri_t *)uptr)->pool,
                           uptr, flags);
}

static MP_INLINE
SV *mpxs_apr_uri_parse(pTHX_ SV *classname, SV *p_sv, const char *uri_string)
{
    SV *uri_sv;
    apr_pool_t *p = mp_xs_sv2_APR__Pool(p_sv);
    modperl_uri_t *uri = modperl_uri_new(p);

    (void)apr_uri_parse(p, uri_string, &uri->uri);

    uri_sv = sv_setref_pv(newSV(0), "APR::URI", (void*)uri);
    mpxs_add_pool_magic(uri_sv, p_sv);

    return uri_sv;
}

static MP_INLINE
char *mpxs_APR__URI_port(pTHX_ apr_uri_t *uri, SV *portsv)
{
    char *port_str = uri->port_str;

    if (portsv) {
        if (SvOK(portsv)) {
            STRLEN len;
            char *port = SvPV(portsv, len);
            uri->port_str = apr_pstrndup(((modperl_uri_t *)uri)->pool,
                                         port, len);
            uri->port = (int)SvIV(portsv);
        }
        else {
            uri->port_str = NULL;
            uri->port = 0;
        }
    }

    return port_str;
}

static MP_INLINE
SV *mpxs_APR__URI_rpath(pTHX_ apr_uri_t *apr_uri)
{
    modperl_uri_t *uri = (modperl_uri_t *)apr_uri;

    if (uri->path_info) {
        int uri_len = strlen(uri->uri.path);
        int n = strlen(uri->path_info);
        int set = uri_len - n;
        if (set > 0) {
            return newSVpv(uri->uri.path, set);
        }
    }
    else {
        if (uri->uri.path) {
            return newSVpv(uri->uri.path, 0);
        }
    }
    return (SV *)NULL;
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
