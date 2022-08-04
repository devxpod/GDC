const fs = require('fs'),
    jose = require('node-jose'),
    jwt = require('jsonwebtoken'),
    jwkToPem = require('jwk-to-pem');


class JWKWrapper {
    constructor(kty = 'RSA', size = 2048, props = {alg: 'RS256', use: 'sig'}, jwk_file_name = 'keys.json') {
        this.kty = kty;
        this.size = size;
        this.props = props;
        this.jwk_file = jwk_file_name;
        this.keyStore = jose.JWK.createKeyStore();
        // 1440 minutes === 24 hours
        this.expirationDuationInMinutes = 1440;
        this.nonce = ""
        this.createJwks();
    }

    // return nonce
    getNonce() {
        return this.nonce;
    }

    setNonce(nonce) {
        this.nonce = nonce;
    }

    // generate & return iat value
    getIat() {
        return Math.floor(Date.now() / 1000);
    }

    // generate & return exp value
    getExp() {
        return Math.floor((Date.now() + (this.expirationDuationInMinutes * 60 * 1000)) / 1000);
    }

    // Create key set and store on local file system
    createJwks() {
      console.log('Creating JWKS store');
      let keyStorePromise = null;
      if (fs.existsSync('./ext_pk/auth0_jwk.json')){
        console.log('Found external JWK file, loading it in store');
        const keyData = fs.readFileSync('./ext_pk/auth0_jwk.json', {encoding:'utf8', flag:'r'});
        const keyJson = JSON.parse(keyData);
        keyStorePromise = jose.JWK.asKeyStore( [keyJson] ).then( ( result ) => {
          // {result} is a jose.JWK.KeyStore
          this.keyStore = result;
        } );
      } else {
        console.log('Generate new JWKS store');
        keyStorePromise = this.keyStore.generate(this.kty, this.size, this.props);
      }

      keyStorePromise.then(result =>
          fs.writeFileSync(
            this.jwk_file,
            JSON.stringify(this.keyStore.toJSON(true), null, '  ')
          )
        );
    }

    // return key set
    getKeys(include_private_key = false, retType = '') {
        retType = (retType.toLowerCase() || '');
        if (retType !== 'json' || !retType) {
            retType = "json";
        }
        if (retType === 'json') {
            return this.keyStore.toJSON(include_private_key);
        }
        return this.keyStore;
    }

    // create token with given payload & options
    async createToken(payload, opt = {}) {
        const key = this.keyStore.all({use: 'sig'})[0];

        // default options if none passed in
        if (Object.keys(opt).length === 0) {
            opt = {compact: true, jwk: key, fields: {typ: 'jwt'}};
        }

        return await jose.JWS.createSign(opt, key)
            .update(JSON.stringify(payload))
            .final();
    }

    async verify(token) {
        console.log('verify token');

        // Use first sig key
        const key = this.keyStore.all({use: 'sig'})[0];
        const v = await jose.JWS.createVerify(this.keyStore).verify(token);
        console.log('token');
        console.log(token);
        console.log('Verify Token');
        console.log(v.header);
        console.log(v.payload.toString());

        // Verify Token with jsonwebtoken
        const publicKey = jwkToPem(key.toJSON());
        const privateKey = jwkToPem(key.toJSON(true), {private: true});

        console.log('public', publicKey);
        console.log('private', privateKey);

        const decoded = jwt.verify(token, publicKey);
        console.log('decoded', decoded);
    }
}

module.exports = new JWKWrapper();
