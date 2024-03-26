#!/usr/local/bin/node

/* global process, require */
/*jshint node:true, esversion:9 */

const fs = require("fs"),
  path = require("path"),
  jwt = require("jsonwebtoken"),
  Getopt = require("node-getopt"),
  version = "20240325-1605",
  OAUTH_PROXY_NAME = "jwt-bearer-oauth",
  getopt = new Getopt([
    ["", "privatekey=ARG", "file containing PEM-encoded private key"],
    ["", "issuer=ARG", "value to use as issuer in the JWT. Default: CLIENT_ID"],
    ["", "audience=ARG", "audience claim for the JWT"],
    ["", "algorithm=ARG", "algorithm, one of the RS* variants"],
    ["", "lifespan=ARG", "lifespan in an expression like 60s, 15m, 1h, etc"]
  ]).bindHelp();

const consoleTimestamp = require("console-stamp");

consoleTimestamp(console, {
  format: ":date(yyyy/mm/dd HH:MM:ss.l) :label"
});

// ========================================================

console.log(
  `Apigee JWT creation tool, version: ${version}\nNode.js ${process.version}\n`
);

// process.argv array starts with 'node' and 'scriptname.js'
const opt = getopt.parse(process.argv.slice(2));

if ( ! opt.options.privatekey) {
  // find a private key
  const availableKeys = fs
    .readdirSync("keys")
    .filter((f) => f.includes('private') && fs.lstatSync(path.join('keys', f)).isFile())
    .map((file) => ({ file, mtime: fs.lstatSync(path.join('keys',file)).mtime }))
    .sort((a, b) => b.mtime.getTime() - a.mtime.getTime());
  if (availableKeys.length == 0) {
    console.log("no keys found in the keys directory. Re-run setup.");
    process.exit(1);
  }
  const selectedKey = availableKeys[0].file;
  console.log(
    `selecting the latest key from the keys directory...${selectedKey}`
  );
  opt.options.privatekey = path.join("keys", selectedKey);
}

if (!opt.options.issuer) {
  if (process.env.CLIENT_ID) {
    console.log(
      `using default value for issuer...${process.env.CLIENT_ID}`
    );
    opt.options.issuer = process.env.CLIENT_ID;
  } else {
    console.log("You must specify an issuer for the JWT");
    getopt.showHelp();
    process.exit(1);
  }
}

if (!opt.options.audience) {
  const defaultAudience = `https://${process.env.APIGEE_HOST}/${OAUTH_PROXY_NAME}`;
  console.log(`using default audience of ${defaultAudience}`);
  opt.options.audience = defaultAudience;
}

const privkey = fs.readFileSync(opt.options.privatekey, 'utf-8'),
  jwtContents = {
    iss: opt.options.issuer,
    sub: opt.options.issuer,
    aud: opt.options.audience,
  };

if (opt.options.scope) {
  jwtContents.scope = opt.options.scope.split(",");
}

const signingOptions = {
  algorithm: opt.options.algorithm || "RS256",
  expiresIn: opt.options.lifespan || "299s"
      };
const token = jwt.sign(jwtContents, privkey, signingOptions);
console.log("token: JWT=%s", token);

const decoded = jwt.decode(token, { json: true, complete: true });
console.log("header: %s", JSON.stringify(decoded.header));
console.log("payload: %s", JSON.stringify(decoded.payload));
