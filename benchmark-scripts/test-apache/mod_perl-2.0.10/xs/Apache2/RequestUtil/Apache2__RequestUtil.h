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
int mpxs_Apache2__RequestRec_push_handlers(pTHX_ request_rec *r,
                                          const char *name,
                                          SV *sv)
{
    return modperl_handler_perl_add_handlers(aTHX_
                                             r, NULL, r->server, r->pool,
                                             name, sv,
                                             MP_HANDLER_ACTION_PUSH);

}

static MP_INLINE
int mpxs_Apache2__RequestRec_set_handlers(pTHX_ request_rec *r,
                                         const char *name,
                                         SV *sv)
{
    return modperl_handler_perl_add_handlers(aTHX_
                                             r, NULL, r->server, r->pool,
                                             name, sv,
                                             MP_HANDLER_ACTION_SET);
}

static MP_INLINE
SV *mpxs_Apache2__RequestRec_get_handlers(pTHX_ request_rec *r,
                                         const char *name)
{
    MpAV **handp =
        modperl_handler_get_handlers(r, NULL, r->server,
                                     r->pool, name,
                                     MP_HANDLER_ACTION_GET);

    return modperl_handler_perl_get_handlers(aTHX_ handp, r->pool);
}

/*
 * XXX: these three should be part of the apache api
 * for protocol module helpers
 */

static MP_INLINE
SV *mpxs_Apache2__RequestRec_new(pTHX_ SV *classname,
                                conn_rec *c,
                                SV *base_pool_sv)
{
    apr_pool_t *p, *base_pool;
    request_rec *r;
    server_rec *s = c->base_server;
    SV *r_sv;

    /* see: httpd-2.0/server/protocol.c:ap_read_request */

    if (base_pool_sv) {
        base_pool = mp_xs_sv2_APR__Pool(base_pool_sv);
    }
    else {
        base_pool = c->pool;
    }

    apr_pool_create(&p, base_pool);
    r = apr_pcalloc(p, sizeof(request_rec));

    r->pool       = p;
    r->connection = c;
    r->server     = s;

    r->request_time = apr_time_now();

    r->user            = NULL;
    r->ap_auth_type    = NULL;

    r->allowed_methods = ap_make_method_list(p, 1);

    r->headers_in      = apr_table_make(p, 1);
    r->subprocess_env  = apr_table_make(r->pool, 1);
    r->headers_out     = apr_table_make(p, 1);
    r->err_headers_out = apr_table_make(p, 1);
    r->notes           = apr_table_make(p, 1);

    r->request_config = ap_create_request_config(p);

    r->proto_output_filters = c->output_filters;
    r->output_filters       = r->proto_output_filters;
    r->proto_input_filters  = c->input_filters;
    r->input_filters        = r->proto_input_filters;

    ap_run_create_request(r);

    r->per_dir_config = s->lookup_defaults;

    r->sent_bodyct     = 0;
    r->read_length     = 0;
    r->read_body       = REQUEST_NO_BODY;
    r->status          = HTTP_OK;
    r->the_request     = "UNKNOWN";

    r->hostname = s->server_hostname;

    r->method          = "GET";
    r->method_number   = M_GET;
    r->uri             = "/";
    r->filename        = (char *)ap_server_root_relative(p, r->uri);

    r->assbackwards    = 1;
    r->protocol        = "UNKNOWN";

    r_sv = sv_setref_pv(newSV(0), "Apache2::RequestRec", (void*)r);

    if (base_pool_sv) {
        mpxs_add_pool_magic(r_sv, base_pool_sv);
    }

    return r_sv;
}

static MP_INLINE
request_rec *mpxs_Apache2__RequestUtil_request(pTHX_ SV *classname, SV *svr)
{
    /* ignore classname */
    return modperl_global_request(aTHX_ svr);
}

static MP_INLINE
int mpxs_Apache2__RequestRec_location_merge(request_rec *r,
                                           char *location)
{
    apr_pool_t *p = r->pool;
    server_rec *s = r->server;
    core_server_config *sconf = ap_get_module_config(s->module_config,
                                                     &core_module);
    ap_conf_vector_t **sec = (ap_conf_vector_t **)sconf->sec_url->elts;
    int num_sec = sconf->sec_url->nelts;
    int i;

    for (i=0; i<num_sec; i++) {
        core_dir_config *entry =
            (core_dir_config *)ap_get_module_config(sec[i],
                                                    &core_module);

        if (strEQ(entry->d, location)) {
            r->per_dir_config =
                ap_merge_per_dir_configs(p, s->lookup_defaults, sec[i]);
            return 1;
        }
    }

    return 0;
}

static MP_INLINE
void mpxs_Apache2__RequestRec_set_basic_credentials(request_rec *r,
                                                   char *username,
                                                   char *password)
{
    char encoded[1024];
    int elen;
    char *auth_value, *auth_cat;

    auth_cat = apr_pstrcat(r->pool,
                           username, ":", password, NULL);
    elen = apr_base64_encode(encoded, auth_cat, strlen(auth_cat));
    encoded[elen] = '\0';

    auth_value = apr_pstrcat(r->pool, "Basic ", encoded, NULL);
    apr_table_setn(r->headers_in, "Authorization", auth_value);
}


static MP_INLINE
int mpxs_Apache2__RequestRec_no_cache(pTHX_ request_rec *r, SV *flag)
{
    int retval = r->no_cache;

    if (flag) {
        r->no_cache = (int)SvIV(flag);
    }

    if (r->no_cache) {
        apr_table_setn(r->headers_out, "Pragma", "no-cache");
        apr_table_setn(r->headers_out, "Cache-control", "no-cache");
    }
    else if (flag) { /* only unset if $r->no_cache(0) */
        apr_table_unset(r->headers_out, "Pragma");
        apr_table_unset(r->headers_out, "Cache-control");
    }

    return retval;
}

static MP_INLINE
SV *mpxs_Apache2__RequestRec_pnotes(pTHX_ request_rec *r, SV *key, SV *val)
{
    MP_dRCFG;

    if (!rcfg) {
        return &PL_sv_undef;
    }

    return modperl_pnotes(aTHX_ &rcfg->pnotes, key, val, r->pool);
}

static MP_INLINE
void mpxs_Apache2__RequestRec_pnotes_kill(pTHX_ request_rec *r)
{
    MP_dRCFG;

    if (!rcfg) {
        return;
    }

    modperl_pnotes_kill(&rcfg->pnotes);
}

#define mpxs_Apache2__RequestRec_dir_config(r, key, sv_val) \
    modperl_dir_config(aTHX_ r, r->server, key, sv_val)

#define mpxs_Apache2__RequestRec_slurp_filename(r, tainted) \
    modperl_slurp_filename(aTHX_ r, tainted)

static MP_INLINE
char *mpxs_Apache2__RequestRec_location(request_rec *r)
{
    MP_dDCFG;

    return dcfg->location;
}

typedef struct {
    PerlInterpreter *perl;
    SV *sv;
} sv_str_header_t;

static int sv_str_header(void *arg, const char *k, const char *v)
{
    sv_str_header_t *svh = (sv_str_header_t *)arg;
    dTHXa(svh->perl);
    Perl_sv_catpvf(aTHX_ svh->sv, "%s: %s\n", k, v);
    return 1;
}

static MP_INLINE
SV *mpxs_Apache2__RequestRec_as_string(pTHX_ request_rec *r)
{
    sv_str_header_t svh;
#ifdef USE_ITHREADS
    svh.perl = aTHX;
#endif

    svh.sv = newSVpv(r->the_request, 0);

    sv_catpvn(svh.sv, "\n", 1);

    apr_table_do((int (*) (void *, const char *, const char *))
                 sv_str_header, (void *) &svh, r->headers_in, NULL);

    Perl_sv_catpvf(aTHX_ svh.sv, "\n%s %s\n", r->protocol, r->status_line);

    apr_table_do((int (*) (void *, const char *, const char *))
                 sv_str_header, (void *) &svh, r->headers_out, NULL);
    apr_table_do((int (*) (void *, const char *, const char *))
                 sv_str_header, (void *) &svh, r->err_headers_out, NULL);

    sv_catpvn(svh.sv, "\n", 1);

    return svh.sv;
}

static MP_INLINE
int mpxs_Apache2__RequestRec_is_perl_option_enabled(pTHX_ request_rec *r,
                                                   const char *name)
{
    return modperl_config_is_perl_option_enabled(aTHX_ r, r->server, name);
}

static MP_INLINE
void mpxs_Apache2__RequestRec_add_config(pTHX_ request_rec *r, SV *lines,
                                         int override, char *path,
                                         int override_options)
{
    const char *errmsg = modperl_config_insert_request(aTHX_ r, lines,
                                                       override, path,
                                                       override_options);
    if (errmsg) {
        Perl_croak(aTHX_ "$r->add_config() has failed: %s", errmsg);
    }
}

/* in order to ensure that s->document_root doesn't get corrupted by
 * modperl users setting its value, restore the original value at the
 * end of each request */
struct mp_docroot_info {
    const char **docroot;
    const char *original;
};

static apr_status_t restore_docroot(void *data)
{
    struct mp_docroot_info *di = (struct mp_docroot_info *)data;
    *di->docroot  = di->original;
    return APR_SUCCESS;
}

static MP_INLINE
const char *mpxs_Apache2__RequestRec_document_root(pTHX_ request_rec *r,
                                                  SV *new_root)
{
    const char *retval = ap_document_root(r);

    if (new_root) {
        struct mp_docroot_info *di;
        core_server_config *conf;
        MP_CROAK_IF_THREADS_STARTED("setting $r->document_root");
        conf = ap_get_module_config(r->server->module_config,
                                    &core_module);
        di = apr_palloc(r->pool, sizeof *di);
        di->docroot = &conf->ap_document_root;
        di->original = conf->ap_document_root;
        apr_pool_cleanup_register(r->pool, di, restore_docroot,
                                  restore_docroot);

        conf->ap_document_root = apr_pstrdup(r->pool, SvPV_nolen(new_root));
    }

    return retval;
}

static apr_status_t child_terminate(void *data) {
    apr_pool_t *pool = (apr_pool_t *)data;

    /* On the first pass, re-register so we end up last */
    if (data) {
        apr_pool_cleanup_register(pool, NULL, child_terminate,
                                  apr_pool_cleanup_null);
    }
    else {
        exit(0);
    }
    return APR_SUCCESS;
}

static MP_INLINE
void mpxs_Apache2__RequestRec_child_terminate(pTHX_ request_rec *r)
{
    MP_CROAK_IF_THREADED_MPM("$r->child_terminate")
    apr_pool_cleanup_register(r->pool, r->pool, child_terminate,
                              apr_pool_cleanup_null);
}



static MP_INLINE
apr_status_t mpxs_ap_register_auth_provider(pTHX_ I32 items, SV **MARK, SV **SP)
{
    apr_pool_t *pool;
    const char *provider_group;
    const char *provider_name;
    const char *provider_version;
    SV *callback1;
    SV *callback2 = NULL;
    int type;

    if (items != 7)
       Perl_croak(aTHX_ "pool, provider_group, provider_name, "
                        "provider_version, callback1, callback2, type");

    if (SvROK(*MARK) && sv_derived_from(*MARK, "APR::Pool")) {
        IV tmp = SvIV((SV*)SvRV(*MARK));
            if (tmp == 0) {
                Perl_croak(aTHX_ "invalid pool object (already destroyed?)");
            }
        pool = INT2PTR(APR__Pool, tmp);
    }
    else {
        Perl_croak(aTHX_ SvROK(*MARK) ?
                       "pool is not of type APR::Pool" :
                       "pool is not a blessed reference");
        }

    MARK++;
    provider_group = (const char *)SvPV_nolen(*MARK);
    MARK++;
    provider_name = (const char *)SvPV_nolen(*MARK);
    MARK++;
    provider_version = (const char *)SvPV_nolen(*MARK);
    MARK++;
    callback1 = newSVsv(*MARK);
    MARK++;
    callback2 = NULL;
    if (SvROK(*MARK)) {
        callback2 = newSVsv(*MARK);
    }
    MARK++;
    type = (int)SvIV(*MARK);

    return modperl_register_auth_provider(pool, provider_group, provider_name,
                                          provider_version, callback1,
                                          callback2, type);
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
