const helpers = require("../modules/helpers");

const token_default_vals = {
    domain: helpers.auth0Url + "/",
    sub: 'samlp|XOAAzure|',
    defaultPermissions: ['chat.admin', 'chat.user'],
    defaultScope: 'openid profile',
    aud: [
        process.env.AUTH0_AUDIENCE || 'xoa_data_portal'
    ],
    given_name: 'test_user_first_name',
    family_name: 'test_user_last_name',
    nickname: 'test_user_nickname',
    name: 'test_user',
    email: 'test_user@xojetaviation.com',
    picture: 'https://en.gravatar.com/avatar.png',
    amr: [
        "mfa"
    ]
};

module.exports = token_default_vals;
