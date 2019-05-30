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

#include "apr_errno.h"

#define mpxs_APR__Status_is_EAGAIN       APR_STATUS_IS_EAGAIN
#define mpxs_APR__Status_is_EACCES       APR_STATUS_IS_EACCES
#define mpxs_APR__Status_is_ENOENT       APR_STATUS_IS_ENOENT
#define mpxs_APR__Status_is_EOF          APR_STATUS_IS_EOF
#define mpxs_APR__Status_is_ECONNABORTED APR_STATUS_IS_ECONNABORTED
#define mpxs_APR__Status_is_ECONNRESET   APR_STATUS_IS_ECONNRESET
#define mpxs_APR__Status_is_TIMEUP       APR_STATUS_IS_TIMEUP

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
