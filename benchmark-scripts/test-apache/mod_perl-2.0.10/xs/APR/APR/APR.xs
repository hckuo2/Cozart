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

#include "mod_perl.h"

#ifdef MP_HAVE_APR_LIBS
#   define APR_initialize apr_initialize
#   define APR_terminate  apr_terminate
#else
#   define APR_initialize()
#   define APR_terminate()
#endif

#ifdef MP_HAVE_APR_LIBS

/* XXX: APR_initialize doesn't initialize apr_hook_global_pool, needed for
 * work outside httpd, so do it manually PR22605 */
#include "apr_hooks.h"
static void extra_apr_init(pTHX)
{
    if (apr_hook_global_pool == NULL) {
        apr_pool_t *global_pool;
        apr_status_t rv = apr_pool_create(&global_pool, NULL);
        if (rv != APR_SUCCESS) {
            PerlIO_printf(PerlIO_stderr(),
                          "Fatal error: unable to create global pool "
                          "for use with by the scoreboard");
        }
        /* XXX: mutex locking? */
        apr_hook_global_pool = global_pool;
    }
    {
        apr_file_t *stderr_apr_handle;
        apr_status_t rv = apr_file_open_stderr(&stderr_apr_handle,
                                               apr_hook_global_pool);
        if (rv != APR_SUCCESS) {
            PerlIO_printf(PerlIO_stderr(),
                          "Fatal error: failed to open stderr ");
        }
        modperl_trace_level_set(stderr_apr_handle, NULL);
    }
    
}
#else
#   define extra_apr_init(aTHX)
#endif

MODULE = APR    PACKAGE = APR

PROTOTYPES: disable

BOOT:
    file = file; /* -Wall */
    APR_initialize();
    extra_apr_init(aTHX);

void
END()

    CODE:
    APR_terminate();
