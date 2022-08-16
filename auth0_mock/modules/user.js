const fs = require('fs');
const path = require('path');

class User {
  constructor(user_file_name, user_file_dir = './') {
    // parse user config file
    this.userlist = JSON.parse(fs.readFileSync(path.join(user_file_dir, user_file_name), 'utf8'));
  }

  // get user object for specific username
  GetUser(username) {
    return this.userlist[username] || {};
  }
}

if (fs.existsSync('./users-local.json')) {
  console.log('using: users-local.json');
  module.exports = new User('users-local.json');
} else {
  console.log('using: users.json');
  module.exports = new User('users.json');
}
