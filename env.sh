#!/bin/bash

# Copyright 2023-2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ==================================
# do not change
export PROXY_NAME=verify-test
export OAUTH_PROXY_NAME=jwt-bearer-oauth
export PRODUCT_NAME=verify-test-1
export APP_NAME=verify-test-1-app
# ==================================

# set the GCP project and the name of the Apigee environment
export APIGEE_PROJECT="<GCP_PROJECT_ID>"
export APIGEE_ENV="<APIGEE_ENVIRONMENT_NAME>"

# specify the hostname at which your API proxies can be reached.
export APIGEE_HOST="<APIGEE_DOMAIN_NAME>"

gcloud config set project "$APIGEE_PROJECT"
