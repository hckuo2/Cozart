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

/* backwards compat for c->keepalive (see ap_mmn.h) */
#if MODULE_MAGIC_NUMBER < 20020625
typedef int ap_conn_keepalive_e;
#endif

static MP_INLINE
apr_socket_t *mpxs_Apache2__Connection_client_socket(pTHX_ conn_rec *c,
                                                    apr_socket_t *s)
{
    apr_socket_t *socket =
        ap_get_module_config(c->conn_config, &core_module);

    if (s) {
        ap_set_module_config(c->conn_config, &core_module, s);
    }

    return socket;
}

static MP_INLINE
const char *mpxs_Apache2__Connection_get_remote_host(pTHX_ conn_rec *c,
                                                    int type,
                                                    ap_conf_vector_t *dir_config)
{
    return ap_get_remote_host(c, (void *)dir_config, type, NULL);
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
