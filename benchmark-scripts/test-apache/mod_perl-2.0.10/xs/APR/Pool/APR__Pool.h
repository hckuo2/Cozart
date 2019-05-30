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

#define MP_APR_POOL_NEW "APR::Pool::new"

typedef struct {
    SV *sv;
#ifdef USE_ITHREADS
    PerlInterpreter *perl;
    modperl_interp_t *interp;
#endif
} mpxs_pool_account_t;

/* XXX: this implementation has a problem with perl ithreads. if a
 * custom pool is allocated, and then a thread is spawned we now have
 * two copies of the pool object, each living in a different perl
 * interpreter, both pointing to the same memory address of the apr
 * pool.
 *
 * need to write a CLONE class method could properly clone the
 * thread's copied object, but it's tricky:
 * - it needs to call parent_get() on the copied object and allocate a
 *   new pool from that parent's pool
 * - it needs to reinstall any registered cleanup callbacks (can we do
 *   that?) may be we can skip those?
 */

#ifndef MP_SOURCE_SCAN
#ifdef USE_ITHREADS
#include "apr_optional.h"
APR_OPTIONAL_FN_TYPE(modperl_interp_unselect) *modperl_opt_interp_unselect;
APR_OPTIONAL_FN_TYPE(modperl_thx_interp_get) *modperl_opt_thx_interp_get;
#endif
#endif

#define MP_APR_POOL_SV_HAS_OWNERSHIP(sv) mpxs_pool_is_custom(sv)

/* before the magic is freed, one needs to carefully detach the
 * dependant pool magic added by mpxs_add_pool_magic (most of the time
 * it'd be a parent pool), and postpone its destruction, until after
 * the child pool is destroyed. Since if we don't do that the
 * destruction of the parent pool will destroy the child pool C guts
 * and when perl unware of that the rug was pulled under the feet will
 * continue destructing the child pool, things will crash
 */
#define MP_APR_POOL_SV_DROPS_OWNERSHIP_RUN(acct) STMT_START {       \
    MAGIC *mg = mg_find(acct->sv, PERL_MAGIC_ext);                  \
    if (mg && mg->mg_obj) {                                         \
        sv_2mortal(mg->mg_obj);                                     \
        mg->mg_obj = (SV *)NULL;                                        \
        mg->mg_flags &= ~MGf_REFCOUNTED;                            \
    }                                                               \
    mg_free(acct->sv);                                              \
    SvIVX(acct->sv) = 0;                                            \
} STMT_END

#ifdef USE_ITHREADS

#define MP_APR_POOL_SV_DROPS_OWNERSHIP(acct) STMT_START {               \
    dTHXa(acct->perl);                                                  \
    MP_APR_POOL_SV_DROPS_OWNERSHIP_RUN(acct);                           \
    if (modperl_opt_interp_unselect && acct->interp) {                  \
        /* this will decrement the interp refcnt until                  \
         * there are no more references, in which case                  \
         * the interpreter will be putback into the mip                 \
         */                                                             \
        MP_TRACE_i(MP_FUNC, "DO: calling interp_unselect(0x%lx)",       \
                   acct->interp);					\
        (void)modperl_opt_interp_unselect(acct->interp);                \
    }                                                                   \
} STMT_END

#define MP_APR_POOL_SV_TAKES_OWNERSHIP(acct_sv, pool) STMT_START {      \
    mpxs_pool_account_t *acct = apr_palloc(pool, sizeof *acct);         \
    acct->sv = acct_sv;                                                 \
    acct->perl = aTHX;                                                  \
    SvIVX(acct_sv) = PTR2IV(pool);                                      \
                                                                        \
    sv_magic(acct_sv, (SV *)NULL, PERL_MAGIC_ext,                           \
             MP_APR_POOL_NEW, sizeof(MP_APR_POOL_NEW));                 \
                                                                        \
    apr_pool_cleanup_register(pool, (void *)acct,                       \
                              mpxs_apr_pool_cleanup,                    \
                              apr_pool_cleanup_null);                   \
                                                                        \
    /* make sure interpreter is not putback into the mip                \
     * until this cleanup has run.                                      \
     */                                                                 \
    if (modperl_opt_thx_interp_get) {                                   \
        if ((acct->interp = modperl_opt_thx_interp_get(aTHX))) {        \
            acct->interp->refcnt++;                                     \
            MP_TRACE_i(MP_FUNC, "TO: (0x%lx)->refcnt incremented to %ld",   \
                       acct->interp, acct->interp->refcnt);                 \
        }                                                               \
    }                                                                   \
} STMT_END

#else /* !USE_ITHREADS */

#define MP_APR_POOL_SV_DROPS_OWNERSHIP MP_APR_POOL_SV_DROPS_OWNERSHIP_RUN

#define MP_APR_POOL_SV_TAKES_OWNERSHIP(acct_sv, pool) STMT_START {      \
    mpxs_pool_account_t *acct = apr_palloc(pool, sizeof *acct);         \
    acct->sv = acct_sv;                                                 \
    SvIVX(acct_sv) = PTR2IV(pool);                                      \
                                                                        \
    sv_magic(acct_sv, (SV *)NULL, PERL_MAGIC_ext,                           \
              MP_APR_POOL_NEW, sizeof(MP_APR_POOL_NEW));                \
                                                                        \
    apr_pool_cleanup_register(pool, (void *)acct,                       \
                              mpxs_apr_pool_cleanup,                    \
                              apr_pool_cleanup_null);                   \
} STMT_END

#endif /* USE_ITHREADS */


/* XXX: should we make it a new global tracing category
 * MOD_PERL_TRACE=p for tracing pool management? */
#define MP_POOL_TRACE_DO 0

#if MP_POOL_TRACE_DO && defined(MP_TRACE)
#define MP_POOL_TRACE modperl_trace
#else
#define MP_POOL_TRACE if (0) modperl_trace
#endif

/* invalidate all Perl objects referencing the data sv stored in the
 * pool and the sv itself. this is needed when a parent pool triggers
 * apr_pool_destroy on its child pools
 */
static MP_INLINE apr_status_t
mpxs_apr_pool_cleanup(void *cleanup_data)
{
    mpxs_pool_account_t *acct = cleanup_data;
    MP_APR_POOL_SV_DROPS_OWNERSHIP(acct);
    return APR_SUCCESS;
}

/**
 * Create a new pool or subpool.
 * @param  parent_pool_obj   an APR::Pool object or an "APR::Pool" class
 * @return                   a new pool or subpool
 */
static MP_INLINE SV *mpxs_apr_pool_create(pTHX_ SV *parent_pool_obj)
{
    apr_pool_t *parent_pool = mpxs_sv_object_deref(parent_pool_obj, apr_pool_t);
    apr_pool_t *child_pool  = NULL;

    MP_POOL_TRACE(MP_FUNC, "parent pool 0x%l", (unsigned long)parent_pool);
    (void)apr_pool_create(&child_pool, parent_pool);

#if APR_POOL_DEBUG
    /* useful for pools debugging, can grep for APR::Pool::new */
    apr_pool_tag(child_pool, MP_APR_POOL_NEW);
#endif

    /* allocation corruption validation: I saw this happening when the
     * same pool was destroyed more than once, should be fixed now,
     * but still the check is not redundant */
    if (child_pool == parent_pool) {
        Perl_croak(aTHX_ "a newly allocated sub-pool 0x%lx "
                   "is the same as its parent 0x%lx, aborting",
                   (unsigned long)child_pool, (unsigned long)parent_pool);
    }

#if APR_POOL_DEBUG
    /* child <-> parent <-> ... <-> top ancestry traversal */
    {
        apr_pool_t *p = child_pool;
        apr_pool_t *pp;

        while ((pp = apr_pool_parent_get(p))) {
            MP_POOL_TRACE(MP_FUNC, "parent 0x%lx, child 0x%lx",
                    (unsigned long)pp, (unsigned long)p);

            if (apr_pool_is_ancestor(pp, p)) {
                MP_POOL_TRACE(MP_FUNC, "0x%lx is a subpool of 0x%lx",
                        (unsigned long)p, (unsigned long)pp);
            }
            p = pp;
        }
    }
#endif

    {
        SV *rv = sv_setref_pv(newSV(0), "APR::Pool", (void*)child_pool);
        SV *sv = SvRV(rv);

        /* Each newly created pool must be destroyed only once. Calling
         * apr_pool_destroy will destroy the pool and its children pools,
         * however a perl object for a sub-pool will still keep a pointer
         * to the pool which was already destroyed. When this object is
         * DESTROYed, apr_pool_destroy will be called again. In the best
         * case it'll try to destroy a non-existing pool, but in the worst
         * case it'll destroy a different valid pool which has been given
         * the same memory allocation wrecking havoc. Therefore we must
         * ensure that when sub-pools are destroyed via the parent pool,
         * their cleanup callbacks will destroy the guts of their perl
         * objects, so when those perl objects, pointing to memory
         * previously allocated by destroyed sub-pools or re-used already
         * by new pools, will get their time to DESTROY, they won't make a
         * mess, trying to destroy an already destroyed pool or even worse
         * a pool allocate in the place of the old one.
         */

        MP_APR_POOL_SV_TAKES_OWNERSHIP(sv, child_pool);

        MP_POOL_TRACE(MP_FUNC, "sub-pool p: 0x%lx, sv: 0x%lx, rv: 0x%lx",
                      (unsigned long)child_pool, sv, rv);

        if (parent_pool) {
            mpxs_add_pool_magic(rv, parent_pool_obj);
        }

        return rv;
    }
}

static MP_INLINE void mpxs_APR__Pool_clear(pTHX_ SV *obj)
{
    apr_pool_t *p = mp_xs_sv2_APR__Pool(obj);
    SV *sv = SvRV(obj);

    if (!MP_APR_POOL_SV_HAS_OWNERSHIP(sv)) {
        MP_POOL_TRACE(MP_FUNC, "parent pool (0x%lx) is a core pool",
                      (unsigned long)p);
        apr_pool_clear(p);
        return;
    }

    MP_POOL_TRACE(MP_FUNC,
                  "parent pool (0x%lx) is a custom pool, sv 0x%lx",
                  (unsigned long)p,
                  (unsigned long)sv);

    apr_pool_clear(p);

    /* apr_pool_clear runs & removes the cleanup, so we need to restore
     * it. Since clear triggers mpxs_apr_pool_cleanup call, our
     * object's guts get nuked too, so we need to restore them too */

    MP_APR_POOL_SV_TAKES_OWNERSHIP(sv, p);
}


typedef struct {
    SV *cv;
    SV *arg;
    apr_pool_t *p;
#ifdef USE_ITHREADS
    PerlInterpreter *perl;
    modperl_interp_t *interp;
#endif
} mpxs_cleanup_t;

/**
 * callback wrapper for Perl cleanup subroutines
 * @param data   internal storage
 */


static apr_status_t mpxs_cleanup_run(void *data)
{
    int count;
    mpxs_cleanup_t *cdata = (mpxs_cleanup_t *)data;
#ifdef USE_ITHREADS
    dTHXa(cdata->perl);
#endif
    dSP;

    ENTER;SAVETMPS;
    PUSHMARK(SP);
    if (cdata->arg) {
        XPUSHs(cdata->arg);
    }
    PUTBACK;

    save_gp(PL_errgv, 1);       /* local *@ */
    count = call_sv(cdata->cv, G_SCALAR|G_EVAL);

    SPAGAIN;

    if (count == 1) {
        (void)POPs; /* the return value is ignored */
    }

    if (SvTRUE(ERRSV)) {
        Perl_warn(aTHX_ "APR::Pool: cleanup died: %s", 
                  SvPV_nolen(ERRSV));
    }

    PUTBACK;
    FREETMPS;LEAVE;

    SvREFCNT_dec(cdata->cv);
    if (cdata->arg) {
        SvREFCNT_dec(cdata->arg);
    }

#ifdef USE_ITHREADS
    if (cdata->interp && modperl_opt_interp_unselect) {
        /* this will decrement the interp refcnt until
         * there are no more references, in which case
         * the interpreter will be putback into the mip
         */
        MP_TRACE_i(MP_FUNC, "calling interp_unselect(0x%lx)", cdata->interp);
        (void)modperl_opt_interp_unselect(cdata->interp);
    }
#endif

    /* the return value is ignored by apr_pool_destroy anyway */
    return APR_SUCCESS;
}

/**
 * register cleanups to run
 * @param p      pool with which to associate the cleanup
 * @param cv     subroutine reference to run
 * @param arg    optional argument to pass to the subroutine
 */
static MP_INLINE void mpxs_apr_pool_cleanup_register(pTHX_ apr_pool_t *p,
                                                     SV *cv, SV *arg)
{
    mpxs_cleanup_t *data =
        (mpxs_cleanup_t *)apr_pcalloc(p, sizeof(*data));

    data->cv = SvREFCNT_inc(cv);
    data->arg = arg ? SvREFCNT_inc(arg) : (SV *)NULL;
    data->p = p;
#ifdef USE_ITHREADS
    data->perl = aTHX;
    /* make sure interpreter is not putback into the mip
     * until this cleanup has run.
     */
    if (modperl_opt_thx_interp_get) {
        if ((data->interp = modperl_opt_thx_interp_get(data->perl))) {
            data->interp->refcnt++;
            MP_TRACE_i(MP_FUNC, "(0x%lx)->refcnt incremented to %ld",
                       data->interp, data->interp->refcnt);
        }
    }
#endif

    apr_pool_cleanup_register(p, data,
                              mpxs_cleanup_run,
                              apr_pool_cleanup_null);
}


static MP_INLINE SV *
mpxs_apr_pool_parent_get(pTHX_ apr_pool_t *child_pool)
{
    apr_pool_t *parent_pool = apr_pool_parent_get(child_pool);

    if (parent_pool) {
        return SvREFCNT_inc(mp_xs_APR__Pool_2obj(parent_pool));
    }
    else {
        MP_POOL_TRACE(MP_FUNC, "pool (0x%lx) has no parents",
                      (unsigned long)child_pool);
        return &PL_sv_undef;
    }
}

/**
 * destroy a pool
 * @param obj    an APR::Pool object
 */
static MP_INLINE void mpxs_apr_pool_DESTROY(pTHX_ SV *obj)
{
    SV *sv = SvRV(obj);

    if (MP_APR_POOL_SV_HAS_OWNERSHIP(sv)) {
        apr_pool_t *p = mpxs_sv_object_deref(obj, apr_pool_t);
        apr_pool_destroy(p);
    }
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
