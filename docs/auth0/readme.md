# Auth0 Mock

The Auth0 Mock is a container that emulates an auth0 login prompt and backend. 
Users login via its login page and are authenticated against info in one of 2 json files.
if `users-local.json` is present it will be used, otherwise `users.json` will be used.

`users.json` / `users-local.json` file format:

```json
{
    "user1": {
        "username": "user1",
        "pw": "user1",
        "permissions": ["user"],
        "scope": "openid profile email",
        "given_name": "John",
        "family_name": "Doe",
        "nickname":"JD",
        "name":"John Doe",
        "email":"john.doe@unknown.com",
        "picture":"https://s.gravatar.com/avatar/4cf8395b3f38515aa3144ccef5a49800?s=480&r=pg&d=https%3A%2F%2Fcdn.auth0.com%2Favatars%2Fjd.png"
    },
    "admin1":{
        "username":"admin1",
        "pw":"admin1",
        "permissions":["admin"],
        "scope":"openid profile email",
        "given_name":"Bob",
        "family_name":"Builder",
        "nickname":"Bob",
        "name":"Bob Builder",
        "email":"bob.builder@build.com",
        "picture":"https://s.gravatar.com/avatar/50a7070e1892b9227579b318cd8b677b?s=480&r=pg&d=https%3A%2F%2Fcdn.auth0.com%2Favatars%2Fpr.png"
    }
}
```

You can go to http://host.docker.internal:3001/ to see a list of all supported routes.

The login page is located at http://host.docker.internal:3001/authorize?redirect_uri=YOUR_CALLBACK_URL  
YOUR_CALLBACK_URL should be the url of your application that is expecting the auth0 response.

