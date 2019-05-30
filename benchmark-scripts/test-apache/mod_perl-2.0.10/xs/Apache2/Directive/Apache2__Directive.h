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

#define mpxs_Apache2__Directive_conftree() ap_conftree

/* XXX: this is only useful for <Perl> at the moment */
static MP_INLINE SV *mpxs_Apache2__Directive_as_string(pTHX_
                                                      ap_directive_t *self)
{
    ap_directive_t *d;
    SV *sv = newSVpv("", 0);

    for (d = self->first_child; d; d = d->next) {
        sv_catpv(sv, d->directive);
        sv_catpv(sv, " ");
        sv_catpv(sv, d->args);
        sv_catpv(sv, "\n");
    }

    return sv;
}


/* Adds an entry to a hash, vivifying hash/array for multiple entries */
static void hash_insert(pTHX_ HV *hash, const char *key,
                        int keylen, const char *args,
                        int argslen, SV *value)
{
    HV *subhash;
    AV *args_array;
    SV **hash_ent = hv_fetch(hash, key, keylen, 0);

    if (value) {
        if (!hash_ent) {
            subhash = newHV();
            (void)hv_store(hash, key, keylen, newRV_noinc((SV *)subhash), 0);
        }
        else {
            subhash = (HV *)SvRV(*hash_ent);
        }

        (void)hv_store(subhash, args, argslen, value, 0);
    }
    else {
        if (hash_ent) {
            if (SvROK(*hash_ent) && (SVt_PVAV == SvTYPE(SvRV(*hash_ent)))) {
                args_array = (AV *)SvRV(*hash_ent);
            }
            else {
                args_array = newAV();
                av_push(args_array, newSVsv(*hash_ent));
                (void)hv_store(hash, key, keylen,
                               newRV_noinc((SV *)args_array), 0);
            }
            av_push(args_array, newSVpv(args, argslen));
        }
        else {
            (void)hv_store(hash, key, keylen, newSVpv(args, argslen), 0);
        }
    }
}

static MP_INLINE SV *mpxs_Apache2__Directive_as_hash(pTHX_
                                                    ap_directive_t *tree)
{
    const char *directive;
    int directive_len;
    const char *args;
    int args_len;

    HV *hash = newHV();
    SV *subtree;

    while (tree) {
        directive = tree->directive;
        directive_len = strlen(directive);
        args = tree->args;
        args_len = strlen(args);

        if (tree->first_child) {

            /* Skip the prefix '<' */
            if ('<' == directive[0]) {
                directive++;
                directive_len--;
            }

            /* Skip the postfix '>' */
            if ('>' == args[args_len-1]) {
                args_len--;
            }

            subtree = mpxs_Apache2__Directive_as_hash(aTHX_ tree->first_child);
            hash_insert(aTHX_ hash, directive, directive_len,
                        args, args_len, subtree);
        }
        else {
            hash_insert(aTHX_ hash, directive, directive_len,
                        args, args_len, (SV *)NULL);
        }

        tree = tree->next;
    }

    return newRV_noinc((SV *)hash);
}

MP_STATIC XS(MPXS_Apache2__Directive_lookup)
{
    dXSARGS;

    if (items < 2 || items > 3) {
            Perl_croak(aTHX_
                       "Usage: Apache2::Directive::lookup(self, key, [args])");
    }

    mpxs_PPCODE({
        Apache2__Directive tree;
        char *value;
        const char *directive;
        const char *args;
        int args_len;
        int directive_len;

        char *key = (char *)SvPV_nolen(ST(1));
        int scalar_context = (G_SCALAR == GIMME_V);

            if (SvROK(ST(0)) && sv_derived_from(ST(0), "Apache2::Directive")) {
                IV tmp = SvIV((SV*)SvRV(ST(0)));
                tree = INT2PTR(Apache2__Directive,tmp);
            }
            else {
                tree = ap_conftree;
            }

            if (items < 3) {
                value = NULL;
            }
            else {
                value = (char *)SvPV_nolen(ST(2));
            }

        while (tree) {
            directive = tree->directive;
            directive_len = strlen(directive);

            /* Remove starting '<' for container directives */
            if (directive[0] == '<') {
                directive++;
                directive_len--;
            }

            if (0 == strncasecmp(directive, key, directive_len)) {

                if (value) {
                    args = tree->args;
                    args_len = strlen(args);

                    /* Skip the postfix '>' */
                    if ('>' == args[args_len-1]) {
                        args_len--;
                    }

                }

                if ( (!value) || (0 == strncasecmp(args, value, args_len)) ) {
                    if (tree->first_child) {
                        XPUSHs(sv_2mortal(mpxs_Apache2__Directive_as_hash(
                                              aTHX_ tree->first_child)));
                    }
                    else {
                       XPUSHs(sv_2mortal(newSVpv(tree->args, 0)));
                    }

                    if (scalar_context) {
                        break;
                    }
                }
            }

            tree = tree->next ? tree->next : NULL;
        }
    });
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
