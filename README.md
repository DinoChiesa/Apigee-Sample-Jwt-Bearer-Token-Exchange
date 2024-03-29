# Apigee Proxy demonstrating jwt-bearer Token Exchange

This API Proxy bundle demonstrates token exchange - a self-signed JWT for an opaque OAuth
token as decribed by [IETF RFC 7523](https://tools.ietf.org/html/rfc7523).

Think of this as an alternative to the "client credentials" grant type,
which was originally defined in [section 4.4 of IETF RFC
6749](https://datatracker.ietf.org/doc/html/rfc6749#section-4.4).

## Disclaimer

This example is not an official Google product, nor is it part of an official
Google product. It's an example.

## Background

The original "client credentials"" request-for-token as described in RFC 6749 looks like this:

```
POST /token HTTP/1.1
Host: server.example.com
Authorization: Basic czZCaGRSa3F0MzpnWDFmQmF0M2JW
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
```

... where the Authorization header contains a base64-encoded form of the client
ID and the client secret, concatenated with a colon (:). If you base64-decode
the above blob (`czZCaGR...`), you get `s6BhdRkqt3:gX1fBat3bV`, which would mean, for this request,
the client ID is `s6BhdRkqt3` and the client secret is `gX1fBat3bV`.

IETF RFC 7523 describes an alternative that relies on public/private key encryption.
Instead of sending a client id+secret pair, the client sends an _assertion_ that is
signed with the client's private key.


The request for token (taken from RFC 7523) looks like so:

```
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded

grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer
&assertion=eyJhbGciOiJFUzI1NiIsImtpZCI6IjE2In0.
eyJpc3Mi[...omitted for brevity...].
J9l-ZhwP[...omitted for brevity...]
```

In the above, the assertion form parameter is a specially-formatted one-time-use
JWT. The client self-signs this token with its _private key_, and then sends it
with the request for an access token. The token dispensary must use the
corresponding _public key_ to verify the signature on the JWT, thereby verifying
that the sender possesses the private key; and at that point the token
dispensary can generate an access token.  In this way, it's a "token exchange" -
exchanging one kind of token for another. The grant type is known as
"jwt-bearer", and uses the grant type identifier of
`urn:ietf:params:oauth:grant-type:jwt-bearer`.  (The version in the example
request above is simply url-encoded.)

This is the style of token exchange process employed [by Google for service-to-service
invocation](https://developers.google.com/identity/protocols/OAuth2ServiceAccount)
for any of the cloud apis (*.googleapis.com), including Cloud Logging, Vertex AI, BigQuery, Apigee, and so on.  [Google
Assistant](https://developers.google.com/actions/identity/oauth2-assertion-flow)
also uses this flow to obtain tokens from _external_ systems.

This example shows you how you can implement this flow within your Apigee
organization, to allow client apps to authenticate via the jwt-bearer approach.

## Why?

One might ask:  _Why not just use a client-credentials grant, relying on the
client ID and secret, as described in [the OAuth Standard (RFC
6749)](https://tools.ietf.org/html/rfc6749)?_

The reason to rely on a signed JWT in the beginning is to avoid sending secrets
across the network. A client secret _is a secret_, and in OAuth Client
Credentials grant, the client must send that secret to the server. That is
something that security experts will advise avoiding, if possible. With the JWT
bearer (RFC 7523) grant, the client does not transmit secrets. Instead it
transmits a digital signature, which is not a secret, but which proves that the
signer possesses the private key.

You might also ask: _Why exchange a JWT for an opaque token? Why not just use the JWT
for every service request?_

The reason to perform a token exchange is to allow fast server-side checking of
access tokens. JWT are (a) large (512 bytes or more), and require time and space to
send over the network, and (b) computationally expensive to parse and verify,
because they use public/private key signatures. On the other hand, an opaque
OAuth token generated by Apigee, is really easy and cheap for a client to
store and transmit (~32 bytes), and easy and fast for Apigee to verify.

Exchanging a JWT for an opaque token allows a faster token transmission, and
faster check of the token on the server side, during many many API requests.

Superior security is probably why Google uses this pattern for the APIs supporting its cloud services.


## Pre-requisites

You need Apigee X to try out this sample.

The helper scripts used here depend on various unix-ish utilities, and also the bash
shell. If you want to invoke calls, you need curl.  You can do all the setup and testing
without these tools, if you like, but I don't provide specific instructions here for
doing so.


## The Proxy Endpoint

This endpoint handles requests for token exchange. The basepath is `/jwt-bearer-oauth`.

It accepts as input a `POST /jwt-bearer-oauth/token`

...with a form-encoded payload (header `Content-Type` must be
`x-www-form-urlencoded`) which includes two form parameters:

* grant_type = `urn:ietf:params:oauth:grant-type:jwt-bearer`
* assertion = a signed JWT

The payload of the JWT should look something like this:
```
{
  "aud": "https://www.example.com/jwt-bearer-oauth/token",
  "sub": "api-key-goes-here",
  "iss": "api-key-goes-here",
  "exp": 1549663491,
  "iat": 1549663191
}
```

The client generates this JWT! Requirements for the JWT:
* signed via RS256 or RS384 using the public key belonging to the developer.
* not expired
* a maximum lifespan no greater than 300 seconds. (It must have both an iat and an exp claim, and the difference must be less than 300 seconds.)
* never previously used to obtain a token.
* aud (==token endpoint URL) and iss (==consumer key) claims are correct
* The issuer must be a valid API Key registered in Apigee. Not expired nor revoked.

If all these checks pass, then the proxy generates an oauth access token, for
the specified consumer key, and returns it. It has an expiry that you (the proxy
designer) can specify or alter; the requester does not get to choose the expiry
of the opaque oauth token. This token can then be used like any other OAuth
access token generated by Apigee, in subsequent requests for service.

As with any OAuth flow in Apigee, there must be a developer entity, an API product, and
an app registered for the developer, authorized on the API Product.

The one twist: The registered app must have a custom attribute named "public_key", and
its contents must be the PEM/PKCS8 encoding of a public key. Replace the newlines with
spaces prior to storing the PEM string, but include the beginning and ending stanzas
(`-----BEGIN PUBLIC KEY-----` and of course all of the encoded data ).


## Provisioning

There are helper scripts in this repo  that assist you in creating all the things required as
described above. To use it, you need a bash shell, with the following tools on your path:

* curl
* npm and node
* openssl
* jq
* sed, tr, sort, xargs

You can use Google Cloud Shell for this purpose; it has all of these
pre-requisites. To get there, start from your Apigee project in GCP, and click
the shell icon:

![cloud-shell](./images/Click-to-open-cloud-shell.png)

> From your own terminal, if you are signed on and you have your project set,
> you can also get to the cloud shell this way:
>
> ```
>  gcloud cloud-shell ssh
> ```


## The Steps:

1. Once you have your terminal opened, Clone the repo!
   ```
   git clone https://github.com/DinoChiesa/Apigee-Sample-Jwt-Bearer-Token-Exchange.git
   ```

2. Now, make sure you are signed in to Google Cloud:
   ```
   gcloud auth login
   ```
   You may see a message advising you that you are already logged in.
   ```
   You are already authenticated with gcloud when running
   inside the Cloud Shell and so do not need to run this
   command. Do you wish to proceed anyway?

   Do you want to continue (Y/n)?
   ```

   Please ignore that,
   and proceed to logging in again.

3. Set your environment.  Change into the directory:
   ```
   cd Apigee-Sample-Jwt-Bearer-Token-Exchange
   ```

   With vi, or with the cloud shell editor, modify the [env.sh](./env.sh) file
   to set the proper values for your purposes.

   Then, source that file:
   ```
   source ./env.sh
   ```

4. Install the dependencies.
   ```
   ./install-dependencies.sh
   ```

5. Set up the Apigee entities: the proxies, the developer, the product, and the app.
   ```
   ./setup-apigee-entities.sh
   ```

   This all will take a few moments.

   > You could do all of this yourself by manually fiddling with the Apigee UI to
   > configure all those things.  If you're not clear on how all of those entities all
   > inter-related, you probably DO want to perform the manual configuration, so you can
   > understand it, but that's not something this sample will cover.


   When the script finishes it will show an output like the following:
   ```
   All the Apigee artifacts are successfully deployed.
   Copy/paste the following statement, into your shell:

   export CLIENT_ID="MzZK7SeX086zD...."

   ```

   Follow that instruction: Copy/paste the CLIENT\_ID statement, to export the variable into your environment.
   ```
   export CLIENT_ID="...your-client-id-here......."
   ```

6. Create a new RSA key pair.

   ```
   ./produce-key-pair.sh
   ```

   A key pair is a matched set of public+private keys.  Cryptographic signatures
   created with the private key can be verified with the public key.

   This script will store the text encoding for the public key and the private key,
   separately, in the keys subdirectory.  For example, the public key will look like this:
   ```
   -----BEGIN PUBLIC KEY-----
   MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiZSjKfXTqnUN6eZkSP8A
   9dVtpP01VlSm1pi8ydMIyrpYpWQLrJNsG3ZpGZ6MahTMnbzlIpGNSa+PgyUHYpnZ
   3l2Qr4tIzSiOmyiPcOEctcj91X+B3dqmFxq2lLLzkZ9im6vJY/G+F1VLOuS/GWot
   kmBWPuWVrZJUfo7xS1nVpP5NVSeYYbYNneMvIbI1CUQWXAYvyUhiiEd47oTrHmTY
   uXyjCclRAPwtHkxcyPgYlcWp07F7ZOMO4cretmB2x50pQwXIPt5h9rhoXtMn8+xy
   JXFR7JhKo27udRn7bLQZt1bMRRfgMl3XgbPDFCTDHxO6zBLjdi4wjbBic/Erz8BQ
   YwIDAQAB
   -----END PUBLIC KEY-----
   ```

7. Associate the public key to the app.
   ```
   ./attach-latest-public-key-to-app.sh
   ```

   This script will set the corresponding public key as a _custom attribute_ on the
   configured application. If there are multiple public keys in the keys directory, the
   script will select the latest one. Since the public key is not a secret, there's no
   problem attaching it as an attribute that can be read by any administrator.

   At runtime, the token dispensing Proxy will be able to read that
   custom attribute, and will thereby have access to the public key.

   While the public key is stored in the app registration within Apigee, the
   private key is stored _only locally_. The client app is the only system that
   has access to the private key.  Any verifier - and in this case that is
   Apigee - should not have access to the private key.


8. Navigate to the Apigee UI and examine the configured entities. Pay attention to the
   configured app, which has the custom attribute containing the public key.
   ![app](./images/app-with-custom-attr.gif)

9. Use the helper script to create a new signed JWT

   This will be used as an assertion that identifies the app.

   With no arguments, the script will select the "latest" key in the directory,
   and will read the private key and sign a JWT with that key.

   Run that script now.
   ```
   node ./create-self-signed-JWT.js
   ```

   > Here again, it's not REQUIRED that you use this tool to create the JWT.  The tool is
   > just a convenience.  You can use any tool to create the JWT. If you want an
   > interactive experience try [this one](https://dinochiesa.github.io/jwt). You would
   > need to provide _your_ private key, the one that the setup script created, and the
   > counterpart to the registered public key. To get it, look in the keys subdirectory.


   The output will include a line like this:
   ```
   [2024/03/26 01:47:37.499] [LOG] JWT=eyJhbGciOiJS...
   ```
   Copy/paste the JWT value into your shell, to set the variable:
   ```
   JWT=eyJhbGciOiJS...full-value-here....
   ```

10. Now, using that self-signed JWT as the "credential", request an opaque access
    token from the Apigee token-dispensing proxy.

    This request uses the jwt-bearer grant type.

    ```
    curl -i -X POST https://${APIGEE_HOST}/jwt-bearer-oauth/token \
          -d assertion=$JWT -d grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer
    ```

    You should see as output, a payload like the following:
    ```
    {
      "access_token": "K0FmSstQI6f4ZB6zs0t9jTIASGcx",
      "issued_at": 1711417959197,
      "expires_in": 1799,
      "api_products": [
        "verify-test-1"
      ],
      "issued": "2024-03-26T01:52:39.197Z",
      "expires": "2024-03-26T02:22:38.197Z"
    }
    ```

11. The access token is now usable; it's a normal access token in Apigee.
    If you like, you can demonstrate that, by invoking the verify proxy:

    ```
    ACCESS_TOKEN=...token.string.from.response.above....

    curl -i -X GET https://${APIGEE_HOST}/verify-test/verify \
          -H "Authorization: Bearer $ACCESS_TOKEN"
    ```



## Exploring and Experimenting

1. Copy/paste the self-signed JWT into a decoder like [here](https://dinochiesa.github.io/jwt)
   You can view the decoded contents of the header, and the payload.

2. Try to re-submit the same self-signed JWT. You should see a rejection from Apigee. The JWT
   is treated as a one-time use assertion.

3. Enable a Debugsession in the Apigee UI.  Observe the proxy execution in the
   request-for-access-token, for both success cases, and rejections.

4. The token exchange enforces a number of requirements on the self-signed JWT.
   You can observe this enforcement by changing the arguments to the
   `create-self-signed-JWT.js` program.

   ```
   node ./create-self-signed-JWT.js [ARGUMENTS]
   ```
   And then submitting the resulting JWT in the request-for-access-token.

   These are some possibilities, where you should see a rejection in the response.

   | token requirement                        | ARGUMENTS to use to trigger the rejection  |
   | ---------------------------------------- | ------------------------------------------ |
   | aud claim must be token dispensing proxy | `--audience foo`                           |
   | lifespan < 300s                          | `--lifespan 600s`                          |
   | lifespan must be determined              | `--omit_iat`                               |
   | issuer must be client ID                 | `--issuer fake-issuer`                     |
   | signed by the appropriate private key    | `--privatekey keys/alternative-key.pem`    |

5. Create a new JWT, with a short lifespan:
   ```
   node ./create-self-signed-JWT.js --lifespan 5s
   ```
   ... and again copy/paste the JWT value into your shell in order to set it as a variable.
   ```
   JWT=eyJh..full-value-here....
   ```

   Then _wait 6 seconds_ or more while the JWT expires. Then, submit that expired JWT in the request for token:
   ```
   curl -i -X POST https://${APIGEE_HOST}/jwt-bearer-oauth/token \
         -d assertion=$JWT -d grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer
   ```
   You should see an appropriate rejection.


## Clean Up

After you are finished experimenting and exploring, you can remove the
developer, the product, and the app, and the proxies from your organization. To
do that, run the cleanup script:

```
./clean-apigee-entities.sh

```

## Copyright and License

This material is [Copyright (c) 2023-2024 Google, LLC.](NOTICE)
and is licensed under the [Apache 2.0 License](LICENSE).
