class Authentication {
  constructor() {
    this.loggedIn = false;
    this.currentUser = {};
  }

  // log a user in
  // if userObj is passed in & not empty then username was correct & only pw needs to be checked
  login(userObj, pw) {
    if (
      userObj.hasOwnProperty('pw') &&
      userObj['pw'].toLowerCase() === pw.toLowerCase()
    ) {
      this.loggedIn = true;
      this.currentUser = userObj;
      return true;
    }
    return false;
  }

  // log a user out
  logout() {
    this.loggedIn = false;
    this.currentUser = {};
    console.log('logged out');
  }

  // return currently logged-in user
  get current_user() {
    return this.currentUser;
  }
}

module.exports = new Authentication();
