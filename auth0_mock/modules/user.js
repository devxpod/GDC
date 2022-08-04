const fs = require('fs');

class User {
  constructor(user_file_name = 'users.json', user_file_dir = './') {
    // parse user config file
    this.userlist = JSON.parse(fs.readFileSync((user_file_dir + user_file_name)));
  }

  // get user object for specific username
  GetUser(username) {
    return (this.userlist[username] || {});
  }
}

module.exports = new User();
