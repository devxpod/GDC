const jwktopem = require('jwk-to-pem'),
  router = require('express').Router(),
  helpers = require('../modules/helpers'),
  middleware = require('../modules/middleware'),
  Jwk_wrapper = require('../modules/jwk-wrapper'),
  id_token_claims = require('../token-claims/id'),
  access_token_claims = require('../token-claims/access');

// Returns JWKS (This is public and does not require login)
router.get('/.well-known/jwks.json', (req, res) => {
  res.status(200).send(Jwk_wrapper.getKeys());
});

// Get the private key used to sign
router.get('/jwks', async (req, res) => {
  res.send(jwktopem(Jwk_wrapper.getKeys(true).keys[0], {private: true}));
});

// Returns access token for user
router.get('/access_token', middleware.checkLogin, async (req, res) => {
  res.send(
    await Jwk_wrapper.createToken(
      access_token_claims('', [`${helpers.auth0Url}/userinfo`])
    )
  );
});

// Returns id token for user
router.get('/id_token', middleware.checkLogin, async (req, res) => {
  res.send(
    await Jwk_wrapper.createToken(helpers.removeNonceIfEmpty(id_token_claims()))
  );
});

// Auth0 token route | returns access && id token
router.post('/oauth/token', middleware.checkLogin, async (req, res) => {
  console.log(Jwk_wrapper.getKeys(true));
  const {client_id} = req.body;
  const access_token_claim = access_token_claims(client_id, [
    `${helpers.auth0Url}/userinfo`
  ]);
  console.log({access_token_claim});
  res.send({
    access_token: await Jwk_wrapper.createToken(access_token_claim),
    expires_in: 86400,
    id_token: await Jwk_wrapper.createToken(
      helpers.removeNonceIfEmpty(id_token_claims(client_id))
    ),
    scope: access_token_claim.scope,
    token_type: 'Bearer'
  });
});

// Used to verify token
router.get('/verify_token_test', middleware.checkLogin, async (req, res) => {
  await Jwk_wrapper.verify(
    await Jwk_wrapper.createToken(helpers.removeNonceIfEmpty(id_token_claims()))
  );
  res.send('done - run docker logs auth0_mock -f to see outputs for debugging');
});

// Used to get userinfo
router.get('/userinfo', middleware.checkLogin, (req, res) => {
  res.json(helpers.removeNonceIfEmpty(id_token_claims()));
});

module.exports = router;
