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

PROXY_NAME=verify-test
OAUTH_PROXY_NAME=jwt-bearer-oauth

create_apiproduct() {
    local product_name=$1
    local ops_file="./configuration-data/operations-defn-${product_name}.json"
    if apigeecli products get --name "${product_name}" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check >>/dev/null 2>&1; then
        printf "  The apiproduct %s already exists!\n" "${product_name}"
    else
        [[ ! -f "$ops_file" ]] && printf "missing operations definition file %s\n" "$ops_file" && exit 1
        apigeecli products create --name "${product_name}" --display-name "${product_name}" \
            --opgrp "$ops_file" \
            --envs "$APIGEE_ENV" --approval auto \
            --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check
    fi
}

create_app() {
    local app_name="$1"
    local developer="$2"
    local product_name="$3"
    local pubkey
    local NUM_APPS
    NUM_APPS=$(apigeecli apps get --name "${app_name}" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check | jq -r .'| length')
    if [[ $NUM_APPS -eq 0 ]]; then
        apigeecli apps create --name "${app_name}" \
            --email "${developer}" --prods "${product_name}" --org "$APIGEE_PROJECT" --token "$TOKEN" \
            --disable-check
    else
        printf "The app already exists...\n"
    fi
}

import_and_deploy_apiproxy() {
    local proxy_name=$1
    apigeecli apis create bundle -f "./bundles/${proxy_name}/apiproxy" -n "$proxy_name" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check
    apigeecli apis deploy --wait --name "$proxy_name" --ovr --org "$APIGEE_PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --disable-check
}

MISSING_ENV_VARS=()
[[ -z "$APIGEE_PROJECT" ]] && MISSING_ENV_VARS+=('APIGEE_PROJECT')
[[ -z "$APIGEE_ENV" ]] && MISSING_ENV_VARS+=('APIGEE_ENV')
[[ -z "$APIGEE_HOST" ]] && MISSING_ENV_VARS+=('APIGEE_HOST')
[[ -z "$PROXY_NAME" ]] && MISSING_ENV_VARS+=('PROXY_NAME')
[[ -z "$OAUTH_PROXY_NAME" ]] && MISSING_ENV_VARS+=('OAUTH_PROXY_NAME')

[[ ${#MISSING_ENV_VARS[@]} -ne 0 ]] && {
    printf -v joined '%s,' "${MISSING_ENV_VARS[@]}"
    printf "Have you sourced the env.sh file? You must set these environment variables: %s\n" "${joined%,}"
    exit 1
}

TOKEN=$(gcloud auth print-access-token)

if [[ ! -d "$HOME/.apigeecli/bin" ]]; then
    printf "Please install dependencies first. Run ./install-dependencies.sh\n"
    exit 1
fi

export PATH=$PATH:$HOME/.apigeecli/bin

printf "Running apigeelint\n"
node_modules/apigeelint/cli.js -s "./bundles/${PROXY_NAME}/apiproxy" -f table.js
node_modules/apigeelint/cli.js -e CC004,ST004,PO007 -s "./bundles/${OAUTH_PROXY_NAME}/apiproxy" -f table.js

printf "Configuring Apigee artifacts...\n"

[[ -z "$SKIP_IMPORT" ]] && {
    printf "Importing and Deploying the Apigee proxies...\n"
    import_and_deploy_apiproxy "$PROXY_NAME"
    import_and_deploy_apiproxy "$OAUTH_PROXY_NAME"
}

printf "Creating API Product\n"
create_apiproduct "${PRODUCT_NAME}"

DEVELOPER_EMAIL="${PROXY_NAME}-apigeesamples@acme.com"
printf "Creating Developer %s\n" "${DEVELOPER_EMAIL}"
if apigeecli developers get --email "${DEVELOPER_EMAIL}" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check >>/dev/null 2>&1; then
    printf "  The developer already exists.\n"
else
    apigeecli developers create --user "${DEVELOPER_EMAIL}" --email "${DEVELOPER_EMAIL}" \
        --first APIProduct --last SampleDeveloper \
        --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check
fi

printf "Checking and possibly Creating Developer Apps\n"
# shellcheck disable=SC2046,SC2162

create_app "${APP_NAME}" "${DEVELOPER_EMAIL}" "${PRODUCT_NAME}"
CLIENT_ID=$(apigeecli apps get --name "${APP_NAME}" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check | jq -r ".[0].credentials[0] | .consumerKey")

export SAMPLE_PROXY_BASEPATH="/v1/samples/$PROXY_NAME"
export CLIENT_ID=${CLIENT_ID}

echo " "
echo "All the Apigee artifacts are successfully deployed."
echo "Copy/paste the following statement, into your shell:"
echo " "
echo "export CLIENT_ID=\"${CLIENT_ID}\""
echo " "
