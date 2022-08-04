const helpers = require( "./modules/helpers" ),
    middleware = require( './modules/middleware' );

const app = require( 'express' )(),
        // https = require( 'https' ),
        // fs = require( 'fs' ),
        bp = require( 'body-parser' ),
        indexRoutes = require( './routes/index' ),
        authRoutes = require( './routes/authentication' ),
        apiRoutes = require( './routes/api' ),
        cors = require( "cors" );

app
        // .use( ( req, res, next ) => {
        //     if( !req.secure ) {
        //         return res.redirect( 'https://' + req.headers.host + req.url );
        //     }
        //     next();
        // } )
        .set( 'view engine', 'ejs' )
        .use( bp.json() )
        .use( bp.urlencoded( {extended: true} ) )
        .use( cors() ).options( "*", cors() )
        .use( middleware.rawReqLogger )
        .use( [indexRoutes, authRoutes, apiRoutes] )
        .listen(helpers.port, '0.0.0.0', () => console.log('http connected to localhost port ', helpers.port));

// https
//     .createServer( {
//         key: fs.readFileSync( './certs/localhost-key.pem' ),
//         cert: fs.readFileSync( './certs/localhost-cert.pem' )
//     }, app )
//     .listen( helpers.port, '0.0.0.0', () => console.log('http connected to localhost port ', helpers.port) );
