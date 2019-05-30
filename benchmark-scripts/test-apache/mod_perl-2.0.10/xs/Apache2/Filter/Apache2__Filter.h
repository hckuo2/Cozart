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

#define mp_xs_sv2_modperl_filter(sv)                                    \
    ((SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG))                      \
     || (Perl_croak(aTHX_ "argument is not a blessed reference"),0) ?   \
     modperl_filter_mg_get(aTHX_ sv) : NULL)

#define mpxs_Apache2__Filter_TIEHANDLE(stashsv, sv)      \
    modperl_newSVsv_obj(aTHX_ stashsv, sv)

#define mpxs_Apache2__Filter_PRINT mpxs_Apache2__Filter_print

static MP_INLINE apr_size_t mpxs_Apache2__Filter_print(pTHX_ I32 items,
                                                      SV **MARK, SV **SP)
{
    modperl_filter_t *modperl_filter;
    apr_size_t bytes = 0;

    mpxs_usage_va_1(modperl_filter, "$filter->print(...)");

    MP_TRACE_f(MP_FUNC, "from %s",
               ((modperl_filter_ctx_t *)modperl_filter->f->ctx)->handler->name);
    if (modperl_filter->mode == MP_OUTPUT_FILTER_MODE) {
        mpxs_write_loop(modperl_output_filter_write,
                        modperl_filter, "Apache2::Filter::print");
    }
    else {
        mpxs_write_loop(modperl_input_filter_write,
                        modperl_filter, "Apache2::Filter::print");
    }

    /* XXX: ap_rflush if $| */

    return bytes;
}

static MP_INLINE apr_size_t mpxs_Apache2__Filter_read(pTHX_ I32 items,
                                                     SV **MARK, SV **SP)
{
    modperl_filter_t *modperl_filter;
    apr_size_t wanted, len=0;
    SV *buffer;

    mpxs_usage_va_2(modperl_filter, buffer, "$filter->read(buf, [len])");

    MP_TRACE_f(MP_FUNC, "from %s",
               ((modperl_filter_ctx_t *)modperl_filter->f->ctx)->handler->name);

    if (items > 2) {
        wanted = SvIV(*MARK);
    }
    else {
        wanted = MP_IOBUFSIZE;
    }

    if (modperl_filter->mode == MP_INPUT_FILTER_MODE) {
        /* XXX: if we ever will have a need to change the read
         * discipline: (input_mode, block, readbytes) from the filter
         * we can provide an accessor method to modify the values
         * supplied by the filter chain */
        len = modperl_input_filter_read(aTHX_ modperl_filter, buffer, wanted);
    }
    else {
        len = modperl_output_filter_read(aTHX_ modperl_filter, buffer, wanted);
    }

    /* must run any set magic */
    SvSETMAGIC(buffer);

    SvTAINTED_on(buffer);

    return len;
}

static MP_INLINE U16 *modperl_filter_attributes(pTHX_ SV *package, SV *cvrv)
{
    return modperl_code_attrs(aTHX_ (CV*)SvRV(cvrv));
}

#ifdef MP_TRACE
#define trace_attr()                                                       \
    MP_TRACE_f(MP_FUNC, "applied %s attribute to %s handler", attribute, \
               HvNAME(stash))
#else
#define trace_attr()
#endif

/* we can't eval at this stage, since the package is not compiled yet,
 * we are still parsing the source.
 */
#define MODPERL_FILTER_ATTACH_ATTR_CODE(cv, string, len)        \
    {                                                           \
        char *str;                                              \
        len -= 2;           /* s/ \( | \) //x       */          \
        string++;           /* skip the opening '(' */          \
        Newx(str, len+1, char);                               \
        Copy(string, str, len+1, char);                         \
        str[len] = '\0';    /* remove the closing ')' */        \
        sv_magic(cv, (SV *)NULL, '~', NULL, -1);                    \
        SvMAGIC(cv)->mg_ptr = str;                              \
    }


MP_STATIC XS(MPXS_modperl_filter_attributes)
{
    dXSARGS;
    U16 *attrs = modperl_filter_attributes(aTHX_ ST(0), ST(1));
    I32 i;
#ifdef MP_TRACE
    HV *stash = gv_stashsv(ST(0), TRUE);
#endif

    for (i=2; i < items; i++) {
        STRLEN len;
        char *pv = SvPV(ST(i), len);
        char *attribute = pv;

        if (strnEQ(pv, "Filter", 6)) {
            pv += 6;
        }

        switch (*pv) {
          case 'C':
            if (strEQ(pv, "ConnectionHandler")) {
                *attrs |= MP_FILTER_CONNECTION_HANDLER;
                trace_attr();
                continue;
            }
          case 'I':
            if (strEQ(pv, "InitHandler")) {
                *attrs |= MP_FILTER_INIT_HANDLER;
                trace_attr();
                continue;
            }
          case 'H':
            if (strnEQ(pv, "HasInitHandler", 14)) {
                STRLEN code_len;
                pv += 14; /* skip over the attr name */
                code_len = len - (pv - attribute);
                MODPERL_FILTER_ATTACH_ATTR_CODE(SvRV(ST(1)), pv, code_len);
                *attrs |= MP_FILTER_HAS_INIT_HANDLER;
                trace_attr();
                continue;
            }
          case 'R':
            if (strEQ(pv, "RequestHandler")) {
                *attrs |= MP_FILTER_REQUEST_HANDLER;
                trace_attr();
                continue;
            }
          default:
            /* XXX: there could be more than one attr to pass through */
            XPUSHs_mortal_pv(attribute);
            XSRETURN(1);
        }
    }

    XSRETURN_EMPTY;
}

static MP_INLINE SV *mpxs_Apache2__Filter_ctx(pTHX_
                                             ap_filter_t *filter,
                                             SV *data)
{
    modperl_filter_ctx_t *ctx = (modperl_filter_ctx_t *)(filter->ctx);

    /* XXX: is it possible that the same filter, during a single
     * request or connection cycle, will be invoked by different perl
     * interpreters? if that happens we are in trouble, if we need to
     * return an SV living in a different interpreter. may be there is
     * a way to use one of the perl internal functions to clone an SV
     * (and it can contain any references)
     */

    if (data != (SV *)NULL) {
        if (ctx->data) {
            if (SvOK(ctx->data) && SvREFCNT(ctx->data)) {
                /* release the previously stored SV so we don't leak
                 * an SV */
                SvREFCNT_dec(ctx->data);
            }
        }

#ifdef USE_ITHREADS
        if (!ctx->interp) {
            ctx->interp = modperl_thx_interp_get(aTHX);
            MP_INTERP_REFCNT_inc(ctx->interp);
        }
#endif
        ctx->data = SvREFCNT_inc(data);
    }

    return ctx->data ? SvREFCNT_inc(ctx->data) : &PL_sv_undef;
}

static MP_INLINE SV *mpxs_Apache2__Filter_seen_eos(pTHX_ I32 items,
                                                  SV **MARK, SV **SP)
{
    modperl_filter_t *modperl_filter;

    if ((items < 1) || (items > 2) || !(mpxs_sv2_obj(modperl_filter, *MARK))) {
        Perl_croak(aTHX_ "usage: $filter->seen_eos([$set])");
    }
    MARK++;

    if (items == 2) {
        modperl_filter->seen_eos = SvTRUE(*MARK) ? 1 : 0;
    }

    return modperl_filter->seen_eos ? &PL_sv_yes : &PL_sv_no;
}

static MP_INLINE
void mpxs_Apache2__RequestRec_add_input_filter(pTHX_ request_rec *r,
                                              SV *callback)
{

    modperl_filter_runtime_add(aTHX_ r,
                               r->connection,
                               MP_FILTER_REQUEST_INPUT_NAME,
                               MP_INPUT_FILTER_MODE,
                               ap_add_input_filter,
                               callback,
                               "InputFilter");
}

static MP_INLINE
void mpxs_Apache2__RequestRec_add_output_filter(pTHX_ request_rec *r,
                                               SV *callback)
{

    modperl_filter_runtime_add(aTHX_ r,
                               r->connection,
                               MP_FILTER_REQUEST_OUTPUT_NAME,
                               MP_OUTPUT_FILTER_MODE,
                               ap_add_output_filter,
                               callback,
                               "OutputFilter");
}

static MP_INLINE
void mpxs_Apache2__Connection_add_input_filter(pTHX_ conn_rec *c,
                                              SV *callback)
{

    modperl_filter_runtime_add(aTHX_ NULL,
                               c,
                               MP_FILTER_CONNECTION_INPUT_NAME,
                               MP_INPUT_FILTER_MODE,
                               ap_add_input_filter,
                               callback,
                               "InputFilter");
}

static MP_INLINE
void mpxs_Apache2__Connection_add_output_filter(pTHX_ conn_rec *c,
                                               SV *callback)
{

    modperl_filter_runtime_add(aTHX_ NULL,
                               c,
                               MP_FILTER_CONNECTION_OUTPUT_NAME,
                               MP_OUTPUT_FILTER_MODE,
                               ap_add_output_filter,
                               callback,
                               "OutputFilter");
}

static MP_INLINE
void mpxs_Apache2__Filter_remove(pTHX_ I32 items, SV **MARK, SV **SP)
{
    modperl_filter_t *modperl_filter;
    ap_filter_t *f;

    if (items < 1) {
        Perl_croak(aTHX_ "usage: $filter->remove()");
    }

    modperl_filter = mp_xs_sv2_modperl_filter(*MARK);

    /* native filter */
    if (!modperl_filter) {
        f = INT2PTR(ap_filter_t *, SvIV(SvRV(*MARK)));
        MP_TRACE_f(MP_FUNC,
                   "   %s\n\n\t non-modperl filter removes itself",
                   f->frec->name);

        /* the filter can reside in only one chain. hence we try to
         * remove it from both, the input and output chains, since
         * unfortunately we can't tell what kind of filter is that and
         * whether the first call was successful
         */
        ap_remove_input_filter(f);
        ap_remove_output_filter(f);
        return;
    }

    f = modperl_filter->f;

    MP_TRACE_f(MP_FUNC, "   %s\n\n\tfilter removes itself",
               ((modperl_filter_ctx_t *)f->ctx)->handler->name);

    if (modperl_filter->mode == MP_INPUT_FILTER_MODE) {
        ap_remove_input_filter(f);
    }
    else {
        ap_remove_output_filter(f);
    }
}

static MP_INLINE
apr_status_t mpxs_Apache2__Filter_fflush(pTHX_ ap_filter_t *filter,
                                        apr_bucket_brigade *brigade)
{
    apr_status_t rc = ap_fflush(filter, brigade);
    /* if users don't bother to check the success, do it on their
     * behalf */
    if (GIMME_V == G_VOID && rc != APR_SUCCESS) {
        modperl_croak(aTHX_ rc, "Apache2::Filter::fflush");
    }

    return rc;
}

static MP_INLINE
apr_status_t mpxs_Apache2__Filter_get_brigade(pTHX_
                                             ap_filter_t *f,
                                             apr_bucket_brigade *bb,
                                             ap_input_mode_t mode,
                                             apr_read_type_e block,
                                             apr_off_t readbytes)
{
    apr_status_t rc = ap_get_brigade(f, bb, mode, block, readbytes);
    /* if users don't bother to check the success, do it on their
     * behalf */
    if (GIMME_V == G_VOID && rc != APR_SUCCESS) {
        modperl_croak(aTHX_ rc, "Apache2::Filter::get_brigade");
    }

    return rc;
}

static MP_INLINE
apr_status_t mpxs_Apache2__Filter_pass_brigade(pTHX_ ap_filter_t *f,
                                              apr_bucket_brigade *bb)
{
    apr_status_t rc = ap_pass_brigade(f, bb);
    /* if users don't bother to check the success, do it on their
     * behalf */
    if (GIMME_V == G_VOID && rc != APR_SUCCESS) {
        modperl_croak(aTHX_ rc, "Apache2::Filter::pass_brigade");
    }

    return rc;
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
