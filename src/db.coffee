#!/usr/bin/env coffee
EJDB = require 'ejdb'
path = require 'path'

# Root dir.
dir = path.resolve __dirname, '../'

# Open db.
module.exports = EJDB.open dir + '/db/apptime.ejdb'