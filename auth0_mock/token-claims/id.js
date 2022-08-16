const Auth = require('../modules/authentication'),
  Jwk_wrapper = require('../modules/jwk-wrapper'),
  token_default_vals = require('./token_defaults');

// id token claims -- claim props should be defined within scope of user aka user.json
// if claim not defined in user.json then uses token default values
const id_token_claims = (aud = '') => {
  const email = Auth.currentUser.email || token_default_vals.email;
  return {
    given_name: Auth.currentUser.given_name || token_default_vals.given_name,
    family_name: Auth.currentUser.family_name || token_default_vals.family_name,
    nickname: Auth.currentUser.nickname || token_default_vals.nickname,
    name: Auth.currentUser.name || token_default_vals.name,
    email: email,
    picture: Auth.currentUser.picture || token_default_vals.picture,
    iss: token_default_vals.domain,
    sub: token_default_vals.sub + email,
    aud: aud || token_default_vals.aud,
    iat: Jwk_wrapper.getIat(),
    exp: Jwk_wrapper.getExp(),
    amr: token_default_vals.amr,
    nonce: Jwk_wrapper.getNonce()
  };
};

module.exports = id_token_claims;
