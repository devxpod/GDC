const User = require('../modules/user'),
  router = require('express').Router(),
  Auth = require('../modules/authentication'),
  Jwk_wrapper = require('../modules/jwk-wrapper'),
  helpers = require('../modules/helpers'),
  id_token_claims = require('../token-claims/id'),
  access_token_claims = require('../token-claims/access');

// path renders login page | used in conjunction with auth0 frontend libs | makes POST to login route
router.get('/authorize', async (req, res) => {
  const {redirect_uri, prompt, state, client_id, nonce, audience} = req.query;
  Jwk_wrapper.setNonce(nonce);
  if (!redirect_uri) {
    return res.status(400).send('missing redirect url');
  }
  if (prompt === 'none') {
    console.log('got silent refresh request');
    if (!Auth.loggedIn) {
      console.log('silent refresh user not logged in');
      const vars = {
        state: state,
        error: 'login_required',
        error_description: 'login_required'
      };
      const params = helpers.buildUriParams(vars);
      const location = `${redirect_uri}?${params}`;
      console.log('Redirect to Location', location);
      return res.writeHead(302, {Location: location}).end();
    }
    console.log('silent refresh user logged in, doing refresh');
    const access_token_claim = access_token_claims(audience, [
      audience,
      `${helpers.auth0Url}/userinfo`
    ]);
    const vars = {
      state: state,
      code: '1234',
      access_token: await Jwk_wrapper.createToken(access_token_claim),
      expires_in: 86400,
      id_token: await Jwk_wrapper.createToken(
        helpers.removeNonceIfEmpty(id_token_claims(audience))
      ),
      scope: access_token_claim.scope,
      token_type: 'Bearer'
    };
    console.log('silent refresh vars', vars);
    const params = helpers.buildUriParams(vars);
    const location = `${redirect_uri}?${params}`;
    console.log('Redirect to Location', location);
    return res.writeHead(302, {Location: location}).end();
  }
  return res.render('../templates/login_page', {
    username: process.env.AUTH0_DEFAULT_USER || 'user1',
    password: process.env.AUTH0_DEFAULT_PASSWORD || 'user1',
    redirect: redirect_uri,
    state
  });
});

// ======================
// login routes
// ======================

// login route | associated with user in user.json file | post made by authorizer route template
router.post('/login', (req, res) => {
  const logMsg = 'username = ' + req.body.username + ' && pw = ' + req.body.pw;
  const redirect = req.query.redirect || '';
  const state = req.query.state;
  // if logged-in user tries to hit login route twice then just log them out and start over
  if (Auth.loggedIn) {
    Auth.logout();
  }
  // if missing username || password params then error
  if (!req.body.username || !req.body.pw) {
    return res.status(400).send('missing username or password');
  }
  // if login fails
  if (!Auth.login(User.GetUser(req.body.username), req.body.pw)) {
    console.error('invalid login - ' + logMsg);
    return res.status(401).send('invalid username or password');
  }
  // all good in the hood
  console.log('Logged in ' + logMsg);

  return res
    .writeHead(302, {
      Location: `${redirect}?code=1234&state=${encodeURIComponent(state)}`
    })
    .end();
});

// login route | alternative to using /authorizer->POST->/login flow
router.get('/login', (req, res) => {
  const logMsg =
    'username = ' + req.query.username + ' && pw = ' + req.query.pw;

  if (Auth.loggedIn) {
    Auth.logout();
  }
  // if missing username || password params then error
  if (!req.query.username || !req.query.pw) {
    return res.status(400).send('missing username or password');
  }
  // if login fails
  if (!Auth.login(User.GetUser(req.query.username), req.query.pw)) {
    console.error('invalid login - ' + logMsg);
    return res.status(401).send('invalid username or password');
  }
  // all good in the hood
  console.log('Logged in ' + logMsg);

  return res
    .status(200)
    .send(
      JSON.stringify(Auth.current_user) +
      '<br><br><b>you may continue with your auth0 needs</b>'
    );
});

// ======================
// logout routes
// ======================

router.get('/logout', (req, res) => {
  const cur_user = JSON.stringify(Auth.current_user);
  Auth.logout();
  console.log(`logged out ${cur_user}`);
  res.status(200).send('logged out');
});

router.get('/v2/logout', (req, res) => {
  const redirect = req.query.returnTo;
  const cur_user = JSON.stringify(Auth.current_user);
  Auth.logout();
  console.log(`logged out ${cur_user}`);
  return res
    .writeHead(302, {
      Location: `${redirect}`
    })
    .end();
});

module.exports = router;
