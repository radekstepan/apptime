#!/usr/bin/env coffee
{ _ } = require 'lodash'
path  = require 'path'
eco   = require 'eco'

# Root dir.
dir = path.resolve __dirname, '../'

# Read our config file.
config = require dir + '/config.coffee'

# Functionalize templates.
_.assign config.email.templates, config.email.templates, (tml) ->
    (context={}, cb) ->
        try
            res = eco.render tml, context
            cb null, res
        catch err
            cb err

module.exports = config