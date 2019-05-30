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

#ifdef WIN32
/* win32 not happy with &PL_sv_no */
#   define SVNO  newSViv(0)
#   define SVYES newSViv(1)
#else
#   define SVNO  &PL_sv_no
#   define SVYES &PL_sv_yes
#endif

#define mpxs_Apache2__RequestRec_TIEHANDLE(stashsv, sv) \
modperl_newSVsv_obj(aTHX_ stashsv, sv)

#define mpxs_Apache2__RequestRec_PRINT  mpxs_Apache2__RequestRec_print
#define mpxs_Apache2__RequestRec_PRINTF mpxs_ap_rprintf
#define mpxs_Apache2__RequestRec_BINMODE(r) \
    r ? SVYES : SVNO /* noop */
#define mpxs_Apache2__RequestRec_CLOSE(r) \
    r ? SVYES : SVNO /* noop */

#define mpxs_Apache2__RequestRec_UNTIE(r, refcnt) \
    (r && refcnt) ? SVYES : SVNO /* noop */

#define mpxs_output_flush(r, rcfg, name)             \
    /* if ($|) */ \
    if (IoFLUSH(PL_defoutgv)) { \
        MP_TRACE_o(MP_FUNC, "(flush) %d bytes [%s]", \
                   rcfg->wbucket->outcnt, \
                   apr_pstrmemdup(rcfg->wbucket->pool, rcfg->wbucket->outbuf, \
                                  rcfg->wbucket->outcnt)); \
        MP_RUN_CROAK(modperl_wbucket_flush(rcfg->wbucket, TRUE), \
                     name);                                      \
    }

static MP_INLINE apr_size_t mpxs_ap_rvputs(pTHX_ I32 items,
                                           SV **MARK, SV **SP)
{
    modperl_config_req_t *rcfg;
    apr_size_t bytes = 0;
    request_rec *r;
    dMP_TIMES;

    mpxs_usage_va_1(r, "$r->puts(...)");

    rcfg = modperl_config_req_get(r);

    MP_START_TIMES();

    MP_CHECK_WBUCKET_INIT("$r->puts");
    mpxs_write_loop(modperl_wbucket_write, rcfg->wbucket,
                    "Apache2::RequestIO::puts");

    MP_END_TIMES();
    MP_PRINT_TIMES("r->puts");

    /* we do not check $| for this method,
     * only in the functions called by the tied interface
     */

    return bytes;
}

static MP_INLINE
SV *mpxs_Apache2__RequestRec_print(pTHX_ I32 items,
                                  SV **MARK, SV **SP)
{
    modperl_config_req_t *rcfg;
    request_rec *r;

    /* bytes must be called bytes */
    apr_size_t bytes = 0;

    /* this also magically assings to r ;-) */
    mpxs_usage_va_1(r, "$r->print(...)");

    rcfg = modperl_config_req_get(r);

    MP_CHECK_WBUCKET_INIT("$r->print");
    mpxs_write_loop(modperl_wbucket_write, rcfg->wbucket,
                    "Apache2::RequestIO::print");

    mpxs_output_flush(r, rcfg, "Apache2::RequestIO::print");

    return bytes ? newSVuv(bytes) : newSVpvn("0E0", 3);
}

static MP_INLINE
apr_size_t mpxs_ap_rprintf(pTHX_ I32 items, SV **MARK, SV **SP)
{
    modperl_config_req_t *rcfg;
    request_rec *r;
    apr_size_t bytes = 0;
    SV *sv;

    mpxs_usage_va(2, r, "$r->printf($fmt, ...)");

    rcfg = modperl_config_req_get(r);

    /* Reduce items by 1 since it otherwise includes the
     * Apache2::RequestRec object, which shouldn't be included in the
     * count of arguments being given to the sprintf() call.
     */
    --items;

    /* XXX: we could have an rcfg->sprintf_buffer to reuse this SV
     * across requests
     */
    sv = sv_newmortal();
    modperl_perl_do_sprintf(aTHX_ sv, items, MARK);
    bytes = SvCUR(sv);

    MP_CHECK_WBUCKET_INIT("$r->printf");

    MP_TRACE_o(MP_FUNC, "%d bytes [%s]", bytes, SvPVX(sv));

    MP_RUN_CROAK(modperl_wbucket_write(aTHX_ rcfg->wbucket,
                                       SvPVX(sv), &bytes),
                 "Apache2::RequestIO::printf");

    mpxs_output_flush(r, rcfg, "Apache2::RequestIO::printf");

    return bytes;
}

/* alias */
#define mpxs_Apache2__RequestRec_WRITE(r, buffer, len, offset) \
    mpxs_Apache2__RequestRec_write(aTHX_ r, buffer, len, offset)

static MP_INLINE
apr_size_t mpxs_Apache2__RequestRec_write(pTHX_ request_rec *r,
                                         SV *buffer, apr_size_t len,
                                         apr_off_t offset)
{
    apr_size_t wlen;
    const char *buf;
    STRLEN avail;
    MP_dRCFG;

    buf = (const char *)SvPV(buffer, avail);

    if (len == -1) {
        wlen = offset ? avail - offset : avail;
    }
    else {
        wlen = len;
    }

    MP_CHECK_WBUCKET_INIT("$r->write");
    MP_RUN_CROAK(modperl_wbucket_write(aTHX_ rcfg->wbucket,
                                       buf+offset, &wlen),
                 "Apache2::RequestIO::write");

    return wlen;
}

static MP_INLINE
void mpxs_Apache2__RequestRec_rflush(pTHX_ I32 items,
                                   SV **MARK, SV **SP)
{
    modperl_config_req_t *rcfg;
    request_rec *r;

    /* this also magically assings to r ;-) */
    mpxs_usage_va_1(r, "$r->rflush()");

    rcfg = modperl_config_req_get(r);

    MP_CHECK_WBUCKET_INIT("$r->rflush");
    MP_TRACE_o(MP_FUNC, "%d bytes [%s]",
               rcfg->wbucket->outcnt,
               apr_pstrmemdup(rcfg->wbucket->pool, rcfg->wbucket->outbuf,
                              rcfg->wbucket->outcnt));
    MP_RUN_CROAK_RESET_OK(r->server,
                          modperl_wbucket_flush(rcfg->wbucket, TRUE),
                          "Apache2::RequestIO::rflush");
}

static MP_INLINE long mpxs_ap_get_client_block(pTHX_ request_rec *r,
                                               SV *buffer, int bufsiz)
{
    long nrd = 0;

    mpxs_sv_grow(buffer, bufsiz);

    nrd = ap_get_client_block(r, SvPVX(buffer), bufsiz);

    if (nrd > 0) {
        mpxs_sv_cur_set(buffer, nrd);
        SvTAINTED_on(buffer);
    }
    else {
        sv_setpvn(buffer, "", 0);
    }

    /* must run any set magic */
    SvSETMAGIC(buffer);

    return nrd;
}

static MP_INLINE
apr_status_t mpxs_setup_client_block(request_rec *r)
{
    if (!r->read_length) {
        apr_status_t rc;

        /* only do this once per-request */
        if ((rc = ap_setup_client_block(r, REQUEST_CHUNKED_ERROR)) != OK) {
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, r->server,
                         "mod_perl: ap_setup_client_block failed: %d", rc);
            return rc;
        }
    }

    return APR_SUCCESS;
}

#define mpxs_should_client_block(r) \
    (r->read_length || ap_should_client_block(r))

#ifndef sv_setpvn_mg
#   define sv_setpvn_mg sv_setpvn
#endif

/* alias */
#define mpxs_Apache2__RequestRec_READ(r, buffer, len, offset) \
    mpxs_Apache2__RequestRec_read(aTHX_ r, buffer, len, offset)

static SV *mpxs_Apache2__RequestRec_read(pTHX_ request_rec *r,
                                         SV *buffer, apr_size_t len,
                                         apr_off_t offset)
{
    SSize_t total;
    STRLEN blen;

    if (!SvOK(buffer)) {
        sv_setpvn_mg(buffer, "", 0);
    }

    (void)SvPV_force(buffer, blen); /* make it a valid PV */

    if (len <= 0) {
        Perl_croak(aTHX_ "The LENGTH argument can't be negative");
    }

    /* handle negative offset */
    if (offset < 0) {
	if (-offset > (int)blen) Perl_croak(aTHX_ "Offset outside string");
        offset += blen;
    }

    mpxs_sv_grow(buffer, len+offset);

    /* need to pad with \0 if offset > size of the buffer */
    if (offset > SvCUR(buffer)) {
        Zero(SvEND(buffer), offset - SvCUR(buffer), char);
    }

    total = modperl_request_read(aTHX_ r, SvPVX(buffer)+offset, len);

    /* modperl_request_read can return only >=0. So it's safe to do this. */
    /* if total==0 we need to set the buffer length in case it is larger */
    mpxs_sv_cur_set(buffer, offset+total);

    /* must run any set magic */
    SvSETMAGIC(buffer);

    SvTAINTED_on(buffer);

    return newSViv(total);
}

static MP_INLINE
SV *mpxs_Apache2__RequestRec_GETC(pTHX_ request_rec *r)
{
    char c[1] = "\0";

    /* XXX: reimplement similar to read() w/o using the deprecated
     * client_block interface */
    if (mpxs_setup_client_block(r) == APR_SUCCESS) {
        if (mpxs_should_client_block(r)) {
            if (ap_get_client_block(r, c, 1) == 1) {
                return newSVpvn((char *)&c, 1);
            }
        }
    }

    return &PL_sv_undef;
}

static MP_INLINE
int mpxs_Apache2__RequestRec_OPEN(pTHX_ SV *self,  SV *arg1, SV *arg2)
{
    char *name;
    STRLEN len;
    SV *arg;
    dHANDLE("STDOUT");

    modperl_io_handle_untie(aTHX_ handle); /* untie *STDOUT */

    if (arg2 && self) {
        arg = newSVsv(arg1);
        sv_catsv(arg, arg2);
    }
    else {
        arg = arg1;
    }

    name = SvPV(arg, len);
    return do_open(handle, name, len, FALSE, O_RDONLY, 0, (PerlIO *)NULL);
}

static MP_INLINE
int mpxs_Apache2__RequestRec_FILENO(pTHX_ request_rec *r)
{
    dHANDLE("STDOUT");
    return PerlIO_fileno(IoOFP(TIEHANDLE_SV(handle)));
}

static MP_INLINE
apr_status_t mpxs_Apache2__RequestRec_sendfile(pTHX_ request_rec *r,
                                              const char *filename,
                                              apr_off_t offset,
                                              apr_size_t len)
{
    apr_size_t nbytes;
    apr_status_t rc;
    apr_file_t *fp;

    rc = apr_file_open(&fp, filename, APR_READ|APR_BINARY,
                       APR_OS_DEFAULT, r->pool);

    if (rc != APR_SUCCESS) {
        if (GIMME_V == G_VOID) {
            modperl_croak(aTHX_ rc,
                          apr_psprintf(r->pool,
                                       "Apache2::RequestIO::sendfile('%s')",
                                       filename));
        }
        else {
            return rc;
        }
    }

    if (!len) {
        apr_finfo_t finfo;
        apr_file_info_get(&finfo, APR_FINFO_NORM, fp);
        len = finfo.size;
        if (offset) {
            len -= offset;
        }
    }

    /* flush any buffered modperl output */
    {
        modperl_config_req_t *rcfg = modperl_config_req_get(r);

        MP_CHECK_WBUCKET_INIT("$r->rflush");
        if (rcfg->wbucket->outcnt) {
            MP_TRACE_o(MP_FUNC, "flushing %d bytes [%s]",
                       rcfg->wbucket->outcnt,
                       apr_pstrmemdup(rcfg->wbucket->pool,
                                      rcfg->wbucket->outbuf,
                                      rcfg->wbucket->outcnt));
            MP_RUN_CROAK(modperl_wbucket_flush(rcfg->wbucket, TRUE),
                         "Apache2::RequestIO::sendfile");
        }
    }

    rc = ap_send_fd(fp, r, offset, len, &nbytes);

    /* apr_file_close(fp); */ /* do not do this */

    if (GIMME_V == G_VOID && rc != APR_SUCCESS) {
        modperl_croak(aTHX_ rc, "Apache2::RequestIO::sendfile");
    }

    return rc;
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
