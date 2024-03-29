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

create_rsa_key_pair() {
    local TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
    [[ -d keys ]] || mkdir keys
    keyid="${TIMESTAMP}"
    privateKeyPkcs8File="keys/key-${TIMESTAMP}-private-rsa.pem"
    publicKeyFile="keys/key-${TIMESTAMP}-public-rsa.pem"
    openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:2048 -out "${privateKeyPkcs8File}" --quiet
    openssl pkey -pubout -inform PEM -outform PEM \
        -in "${privateKeyPkcs8File}" -out "${publicKeyFile}"
    printf "Created keypair\n  private: ${privateKeyPkcs8File}\n  public: ${publicKeyFile}\n"

    # also generate an alternative key, for testing purposes later
    openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:2048 -out "keys/alternative-key.pem" --quiet
}

create_rsa_key_pair
