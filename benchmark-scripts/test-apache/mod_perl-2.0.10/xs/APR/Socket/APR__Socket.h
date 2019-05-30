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
apr_size_t mpxs_APR__Socket_recv(pTHX_ apr_socket_t *socket,
                                 SV *buffer,
                                 apr_size_t len)
{
    apr_status_t rc;

    mpxs_sv_grow(buffer, len);
    rc = apr_socket_recv(socket, SvPVX(buffer), &len);

    if (!(rc == APR_SUCCESS || rc == APR_EOF)) {
        modperl_croak(aTHX_ rc, "APR::Socket::recv");
    }

    mpxs_sv_cur_set(buffer, len);
    SvTAINTED_on(buffer);
    return len;
}

static MP_INLINE
apr_size_t mpxs_apr_socket_send(pTHX_ apr_socket_t *socket,
                                SV *sv_buf, SV *sv_len)
{
    apr_size_t buf_len;
    char *buffer = SvPV(sv_buf, buf_len);

    if (sv_len) {
        if (buf_len < SvIV(sv_len)) {
            Perl_croak(aTHX_ "the 3rd arg (%d) is bigger than the "
                       "length (%d) of the 2nd argument",
                       (int)SvIV(sv_len), buf_len);
        }
        buf_len = SvIV(sv_len);
    }

    MP_RUN_CROAK(apr_socket_send(socket, buffer, &buf_len),
                 "APR::Socket::send");

    return buf_len;
}

static MP_INLINE
apr_interval_time_t mpxs_apr_socket_timeout_get(pTHX_ I32 items,
                                                SV **MARK, SV **SP)
{
    apr_interval_time_t t;
    APR__Socket APR__Socket;

    /* this also magically assings to APR_Socket ;-) */
    mpxs_usage_va_1(APR__Socket, "$socket->timeout_get()");

    MP_RUN_CROAK(apr_socket_timeout_get(APR__Socket, &t),
                 "APR::Socket::timeout_get");
    return t;
}

static MP_INLINE
void mpxs_APR__Socket_timeout_set(pTHX_ apr_socket_t *socket,
                                 apr_interval_time_t t)
{
    MP_RUN_CROAK(apr_socket_timeout_set(socket, t),
                 "APR::Socket::timeout_set");
}



static MP_INLINE
apr_int32_t mpxs_APR__Socket_opt_get(pTHX_ apr_socket_t *socket,
                                     apr_int32_t opt)
{
    apr_int32_t val;
    MP_RUN_CROAK(apr_socket_opt_get(socket, opt, &val),
                 "APR::Socket::opt_get");
    return val;
}

static MP_INLINE
void mpxs_APR__Socket_opt_set(pTHX_ apr_socket_t *socket, apr_int32_t opt,
                              apr_int32_t val)
{
    MP_RUN_CROAK(apr_socket_opt_set(socket, opt, val),
                 "APR::Socket::opt_set");
}

static MP_INLINE
apr_status_t mpxs_APR__Socket_poll(apr_socket_t *socket,
                                   apr_pool_t *pool,
                                   apr_interval_time_t timeout,
                                   apr_int16_t reqevents)
{
    apr_pollfd_t fd;
    apr_int32_t nsds;

    /* what to poll */
    fd.p         = pool;
    fd.desc_type = APR_POLL_SOCKET;
    fd.desc.s    = socket;
    fd.reqevents = reqevents;
    fd.rtnevents = 0; /* XXX: not really necessary to set this */

    return apr_poll(&fd, 1, &nsds, timeout);
}

#ifndef WIN32
static MP_INLINE int mpxs_APR__Socket_fileno(pTHX_ apr_socket_t *socket)
{
    apr_os_sock_t s;
    apr_os_sock_get(&s, socket);
    return s;
}
#endif

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
