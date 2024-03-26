// groomTokenResponse.js
// ------------------------------------------------------------------
//
// Tweaks the generated OAuth token response.
//
// last saved: <2024-March-25 18:33:11>
/* global dateFormat, response, context */
var b1 = JSON.parse(response.content);

if (b1.access_token) {
  b1.issued_at = parseInt(b1.issued_at, 10);
  b1.expires_in = parseInt(b1.expires_in, 10);
  var b2 = {
    access_token: b1.access_token,
    issued_at: b1.issued_at,
    expires_in: b1.expires_in,
    api_products: b1.api_product_list_json,
    // and format the time values in human-readable forms
    issued: new Date(b1.issued_at).toISOString(),
    expires: new Date(b1.issued_at + b1.expires_in * 1000).toISOString()
  };

  context.setVariable("response.content", JSON.stringify(b2, null, 2) + "\n");
}
