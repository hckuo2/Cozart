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

#if AP_SERVER_MAJORVERSION_NUMBER>2 || AP_SERVER_MINORVERSION_NUMBER>=3
#define loglevel log.level

static MP_INLINE
int mpxs_Apache2__ServerRec_is_virtual(pTHX_ server_rec *s, SV *val)
{
    int retval = s->is_virtual;

    if (val) {
        s->is_virtual = SvIV(val);
    }

    return retval;
}

#endif
