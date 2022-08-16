const Auth = require('../modules/authentication'),
  Jwk_wrapper = require('../modules/jwk-wrapper'),
  token_default_vals = require('./token_defaults');

// https://auth0.com/docs/secure/tokens/json-web-tokens/json-web-token-claims
//
// auth token claims -- claim props should be defined within scope of user aka user.json
// if claim not defined in user.json then uses token default values
const access_token_claims = (azp = '', aud = []) => {
  const email = Auth.currentUser.email || token_default_vals.email;
  return {
    iss: token_default_vals.domain,
    sub: token_default_vals.sub + email,
    aud: token_default_vals.aud.concat(aud),
    iat: Jwk_wrapper.getIat(),
    exp: Jwk_wrapper.getExp(),
    azp: azp,
    scope: Auth.currentUser.scope || token_default_vals.defaultPermissions,
    permissions:
      Auth.currentUser.permissions || token_default_vals.defaultScope
  };
};

module.exports = access_token_claims;
