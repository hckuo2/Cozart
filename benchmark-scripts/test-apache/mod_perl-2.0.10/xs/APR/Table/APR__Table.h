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

#define mpxs_APR__Table_STORE   apr_table_set
#define mpxs_APR__Table_DELETE  apr_table_unset
#define mpxs_APR__Table_CLEAR   apr_table_clear

#define MPXS_DO_TABLE_N_MAGIC_RETURN(call)                              \
    apr_pool_t *p = mp_xs_sv2_APR__Pool(p_sv);                          \
    apr_table_t *t = call;                                              \
    SV *t_sv = modperl_hash_tie(aTHX_ "APR::Table", (SV *)NULL, t);     \
    mpxs_add_pool_magic(t_sv, p_sv);                                    \
    return t_sv;

static MP_INLINE SV *mpxs_APR__Table_make(pTHX_ SV *p_sv, int nelts)
{
    MPXS_DO_TABLE_N_MAGIC_RETURN(apr_table_make(p, nelts));
}


static MP_INLINE SV *mpxs_APR__Table_copy(pTHX_ apr_table_t *base, SV *p_sv)
{
    MPXS_DO_TABLE_N_MAGIC_RETURN(apr_table_copy(p, base));
}

static MP_INLINE SV *mpxs_APR__Table_overlay(pTHX_ apr_table_t *base,
                                             apr_table_t *overlay, SV *p_sv)
{
    MPXS_DO_TABLE_N_MAGIC_RETURN(apr_table_overlay(p, overlay, base));
}


typedef struct {
    SV *cv;
    apr_hash_t *filter;
    PerlInterpreter *perl;
} mpxs_table_do_cb_data_t;

typedef int (*mpxs_apr_table_do_cb_t)(void *, const char *, const char *);

static int mpxs_apr_table_do_cb(void *data,
                                const char *key, const char *val)
{
    mpxs_table_do_cb_data_t *tdata = (mpxs_table_do_cb_data_t *)data;
    dTHXa(tdata->perl);
    dSP;
    int rv = 0;

    /* Skip completely if something is wrong */
    if (!(tdata && tdata->cv && key && val)) {
        return 0;
    }

    /* Skip entries if not in our filter list */
    if (tdata->filter) {
        if (!apr_hash_get(tdata->filter, key, APR_HASH_KEY_STRING)) {
            return 1;
        }
    }

    ENTER;
    SAVETMPS;

    PUSHMARK(sp);
    XPUSHs(sv_2mortal(newSVpv(key,0)));
    XPUSHs(sv_2mortal(newSVpv(val,0)));
    PUTBACK;

    rv = call_sv(tdata->cv, 0);
    SPAGAIN;
    rv = (1 == rv) ? POPi : 1;
    PUTBACK;

    FREETMPS;
    LEAVE;

    /* rv of 0 aborts the traversal */
    return rv;
}

static MP_INLINE
int mpxs_apr_table_do(pTHX_ I32 items, SV **MARK, SV **SP)
{
    apr_table_t *table;
    SV *sub;
    mpxs_table_do_cb_data_t tdata;

    mpxs_usage_va_2(table, sub, "$table->do(sub, [@filter])");

    tdata.cv = sub;
    tdata.filter = NULL;
#ifdef USE_ITHREADS
    tdata.perl = aTHX;
#endif

    if (items > 2) {
        char *filter_entry;
        STRLEN len;

        tdata.filter = apr_hash_make(apr_table_elts(table)->pool);

        while (MARK <= SP) {
            filter_entry = SvPV(*MARK, len);
            apr_hash_set(tdata.filter, filter_entry, len, "1");
            MARK++;
        }
    }

    /* XXX: would be nice to be able to call apr_table_vdo directly,
     * but I don't think it's possible to create/populate something
     * that smells like a va_list with our list of filters specs
     */

    apr_table_do(mpxs_apr_table_do_cb, (void *)&tdata, table, NULL);

    /* Free tdata.filter or wait for the pool to go away? */

    /* XXX: return return value of apr_table_do once we require newer httpd */
    return 1;
}

static MP_INLINE int mpxs_APR__Table_EXISTS(apr_table_t *t, const char *key)
{
    return (NULL == apr_table_get(t, key)) ? 0 : 1;
}

/* Note: SvCUR is used as the iterator state counter, why not ;-? */
#define mpxs_apr_table_iterix(sv) \
SvCUR(SvRV(sv))

#define mpxs_apr_table_nextkey(t, sv) \
   ((apr_table_entry_t *) \
     apr_table_elts(t)->elts)[mpxs_apr_table_iterix(sv)++].key

static MP_INLINE const char *mpxs_APR__Table_NEXTKEY(pTHX_ SV *tsv, SV *key)
{
    apr_table_t *t;
    SV *rv = modperl_hash_tied_object_rv(aTHX_ "APR::Table", tsv);
    if (!SvROK(rv)) {
        Perl_croak(aTHX_ "Usage: $table->NEXTKEY($key): "
                   "first argument not an APR::Table object");
    }

    t = INT2PTR(apr_table_t *, SvIVX(SvRV(rv)));

    if (apr_is_empty_table(t)) {
        return NULL;
    }

    if (key == NULL) {
        mpxs_apr_table_iterix(rv) = 0; /* reset iterator index */
    }

    if (mpxs_apr_table_iterix(rv) < apr_table_elts(t)->nelts) {
        return mpxs_apr_table_nextkey(t, rv);
    }

    mpxs_apr_table_iterix(rv) = 0;

    return NULL;
}

/* Try to shortcut apr_table_get by fetching the key using the current
 * iterator (unless it's inactive or points at different key).
 */
static MP_INLINE const char *mpxs_APR__Table_FETCH(pTHX_ SV *tsv,
                                                   const char *key)
{
    SV* rv = modperl_hash_tied_object_rv(aTHX_ "APR::Table", tsv);
    const int i = mpxs_apr_table_iterix(rv);
    apr_table_t *t = INT2PTR(apr_table_t *, SvIVX(SvRV(rv)));
    const apr_array_header_t *arr = apr_table_elts(t);
    apr_table_entry_t *elts = (apr_table_entry_t *)arr->elts;

    if (i > 0 && i <= arr->nelts && !strcasecmp(key, elts[i-1].key)) {
        return elts[i-1].val;
    }
    else {
        return apr_table_get(t, key);
    }
}


MP_STATIC XS(MPXS_apr_table_get)
{
    dXSARGS;

    if (items != 2) {
        Perl_croak(aTHX_ "Usage: $table->get($key)");
    }

    mpxs_PPCODE({
        APR__Table t = modperl_hash_tied_object(aTHX_ "APR::Table", ST(0));
        const char *key = (const char *)SvPV_nolen(ST(1));

        if (!t) {
            XSRETURN_UNDEF;
        }

        if (GIMME_V == G_SCALAR) {
            const char *val = apr_table_get(t, key);

            if (val) {
                XPUSHs(sv_2mortal(newSVpv((char*)val, 0)));
            }
        }
        else {
            const apr_array_header_t *arr = apr_table_elts(t);
            apr_table_entry_t *elts = (apr_table_entry_t *)arr->elts;
            int i;

            for (i = 0; i < arr->nelts; i++) {
                if (!elts[i].key || strcasecmp(elts[i].key, key)) {
                    continue;
                }
                XPUSHs(sv_2mortal(newSVpv(elts[i].val,0)));
            }
        }
    });

}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
