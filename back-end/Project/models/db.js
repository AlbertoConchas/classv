const mongoose = require('mongoose');

var mongouri = 'mongodb://'+process.env.DBUSERNAME+':'+process.env.DBPASSWORD+'@'+process.env.MONGODB_HOST+':'+process.env.MONGODB_PORT+'/'+process.env.MONGODB_DBNAME;

mongoose.connect(mongouri, (err) => {
    if (!err) { console.log('MongoDB connection succeeded.'); }
    else { console.log('Error in MongoDB connection : ' + JSON.stringify(err, undefined, 2)); }
});

require('./user.model');
