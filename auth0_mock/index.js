const helpers = require('./modules/helpers');
const middleware = require('./modules/middleware');

const app = require('express')(),
  bp = require('body-parser'),
  indexRoutes = require('./routes/index'),
  authRoutes = require('./routes/authentication'),
  apiRoutes = require('./routes/api'),
  cors = require('cors');

app
  .set('view engine', 'ejs')
  .use(bp.json())
  .use(bp.urlencoded({extended: true}))
  .use(cors())
  .options('*', cors())
  .use(middleware.rawReqLogger)
  .use([indexRoutes, authRoutes, apiRoutes])
  .listen(helpers.port, '0.0.0.0', () =>
    console.log('http connected to localhost port ', helpers.port)
  );
