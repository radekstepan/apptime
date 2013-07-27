#!/usr/bin/env coffee
path       = require 'path'
flatiron   = require 'flatiron'
connect    = require 'connect' 
middleware = require 'apps-a-middleware'

# Root dir.
dir = path.resolve __dirname, '../'

respond = require './res.coffee'  # responder

# Start flatiron dash app.
app = flatiron.app
app.use flatiron.plugins.http,
    before: [
        # Static file serving.
        connect.static dir + '/public'
        # Apps/A.
        middleware
            apps: [
                'file://../../../../src' # interesting...
            ]
    ]

# API toor.
app.router.path '/api', ->
    @get -> respond @res

# Dash blast off.
module.exports = (cb) -> app.start process.env.PORT, cb