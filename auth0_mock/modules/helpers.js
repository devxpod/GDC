let helpers = {};

// helper to remove prop if its empty
helpers.removeNonceIfEmpty = (obj) => {
  if ('nonce' in obj && obj.nonce === '') {
    delete obj.nonce;
  }
  return obj;
};

helpers.removeTrailingSlash = (str) => {
  return str.endsWith('/') ? str.slice(0, -1) : str;
};

helpers.buildUriParams = (vars) =>
  Object.keys(vars)
    .reduce((a, k) => {
      a.push(`${k}=${encodeURIComponent(vars[k])}`);
      return a;
    }, [])
    .join('&');

helpers.port = process.env.APP_PORT || 3001;
// auth0 mock url pieces
helpers.auth0Url = process.env.AUTH0_URL || 'http://localhost:' + helpers.port;

module.exports = helpers;
