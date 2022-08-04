const Authentication = require('./authentication');

// add all middleware to obj
let middleware = {};

// checks if user is logged in
middleware.checkLogin = (req, res, next) => {
    if (Authentication.loggedIn) {
        return next();
    }
    console.log('Error user not logged in');
    return res.status(401).send('Unauthorized. User not logged in');
};

middleware.rawReqLogger = (req, res, next) => {
    // Debug helper | logs props for all requests
    console.log("==========================================");
    console.log(new Date().toISOString(), "raw request logging");
    console.log("==========================================");
    console.log("route " + req.path + " hit \n");
    console.log("req headers " + JSON.stringify(req.headers) + "\n");
    console.log("req body " + JSON.stringify(req.body) + "\n");
    console.log("req params " + JSON.stringify(req.params) + "\n");
    console.log("==========================================");

    // Response handling
    // const oldWrite = res.write;
    // const oldEnd = res.end;
    // const chunks = [];
    // res.write = function ( chunk ) {
    //     chunks.push( new Buffer( chunk ) );
    //     oldWrite.apply( res, arguments );
    // };
    // res.end = function ( chunk ) {
    //     if( chunk ) {
    //         chunks.push( new Buffer( chunk ) );
    //     }
    //     const body = Buffer.concat( chunks ).toString( 'utf8' );
    //     console.log( "resp body \n" + body );
    //     console.log( "==========================================" );
    //     oldEnd.apply( res, arguments );
    // };

    return next();
};

module.exports = middleware;
