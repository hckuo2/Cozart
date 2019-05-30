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

#define mpxs_Apache2__Module_top_module() ap_top_module

static MP_INLINE int mpxs_Apache2__Module_loaded(pTHX_ char *name)
{
    char nameptr[256];
    char *base;
    module *modp;

    /* Does the module name have a '.' in it ? */
    if ((base = ap_strchr(name, '.'))) {
        int len = base - name;

        memcpy(nameptr, name, len);
        memcpy(nameptr + len, ".c\0", 3);

        /* check if module is loaded */
        if (!(modp = ap_find_linked_module(nameptr))) {
            return 0;
        }

        if (*(base + 1) == 'c') {
            return 1;
        }

        /* if it ends in '.so', check if it was dynamically loaded */
        if ((strlen(base+1) == 2) &&
            (*(base + 1) == 's') && (*(base + 2) == 'o') &&
            modp->dynamic_load_handle)
        {
            return 1;
        }

        return 0;
    }
    else {
        return modperl_perl_module_loaded(aTHX_ name);
    }
}

static MP_INLINE SV *mpxs_Apache2__Module_get_config(pTHX_
                                                    SV *pmodule,
                                                    server_rec *s,
                                                    ap_conf_vector_t *v)
{
    SV *obj = modperl_module_config_get_obj(aTHX_ pmodule, s, v);

    return SvREFCNT_inc(obj);
}

static MP_INLINE
int mpxs_Apache2__Module_ap_api_major_version(pTHX_ module *mod)
{
    return mod->version;
}

static MP_INLINE
int mpxs_Apache2__Module_ap_api_minor_version(pTHX_ module *mod)
{
    return mod->minor_version;
}

static MP_INLINE void mpxs_Apache2__Module_add(pTHX_
                                              char *package,
                                              SV *cmds)
{
    const char *error;
    server_rec *s;

    if (!(SvROK(cmds) && (SvTYPE(SvRV(cmds)) == SVt_PVAV))) {
        Perl_croak(aTHX_ "Usage: Apache2::Module::add(__PACKAGE__, [])");
    }

    s = modperl_global_get_server_rec();
    error = modperl_module_add(s->process->pconf, s, package, cmds);

    if (error) {
        Perl_croak(aTHX_ "Apache2::Module::add(%s) failed : %s",
                   package, error);
    }

    return;
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
