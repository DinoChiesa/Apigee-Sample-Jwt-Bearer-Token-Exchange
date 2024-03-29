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

# use nullglob in case there are no matching files
shopt -s nullglob

keys=(./keys/key-*.pem)

if [[ ${#keys[@]} -lt 2 ]]; then
    printf "No keys found; please create a pair by running produce_key_pair.sh\n"
    exit
fi

sorted=($(echo "${keys[@]}" | tr ' ' '\n' | sort | xargs))

MISSING_ENV_VARS=()
[[ -z "$APIGEE_PROJECT" ]] && MISSING_ENV_VARS+=('APIGEE_PROJECT')
[[ -z "$PROXY_NAME" ]] && MISSING_ENV_VARS+=('PROXY_NAME')
[[ -z "$APP_NAME" ]] && MISSING_ENV_VARS+=('APP_NAME')

[[ ${#MISSING_ENV_VARS[@]} -ne 0 ]] && {
    printf -v joined '%s,' "${MISSING_ENV_VARS[@]}"
    printf "Have you sourced the env.sh file? You must set these environment variables: %s\n" "${joined%,}"
    exit 1
}

if [[ ! -d "$HOME/.apigeecli/bin" ]]; then
    printf "Please install dependencies first. Run ./install-dependencies.sh\n"
    exit 1
fi

export PATH=$PATH:$HOME/.apigeecli/bin

publicKeyFile="${sorted[${#sorted[@]} - 1]}"
#privateKeyFile="${sorted[${#sorted[@]} - 2]}"
printf "using public key: %s\n" "${publicKeyFile}"

# read file, replace newlines with spaces
pubkey=$(sed 's/$/ /' "$publicKeyFile" | tr -d '\n')

# get the keyid
IFS='-' read -r -a parts <<<"$publicKeyFile"
keyid="${parts[1]}-${parts[2]}"
#echo "keyid: $keyid"

DEVELOPER_EMAIL="${PROXY_NAME}-apigeesamples@acme.com"

TOKEN=$(gcloud auth print-access-token)

printf "setting public key as custom attribute on app %s\n" "${app_name}"
apigeecli apps update --name "${APP_NAME}" \
    --email "${DEVELOPER_EMAIL}" --org "$APIGEE_PROJECT" --token "$TOKEN" \
    --attrs public_key="${pubkey}",keyid="${keyid}",jwt_algorithm=RS256 \
    --disable-check
