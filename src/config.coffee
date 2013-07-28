#!/usr/bin/env coffee
{ _ } = require 'lodash'
path  = require 'path'
eco   = require 'eco'

# Provided path?
if p = process.env.CONFIG
    p = path.resolve(__dirname, '..', p) unless p[0] is '/'
else
    p = path.resolve __dirname, '../config.example.coffee'

# Read our config file.
config = require p # throw-y

# Functionalize templates.
_.assign config.email.templates, config.email.templates, (tml) ->
    (context={}, cb) ->
        try
            res = eco.render tml, context
            cb null, res
        catch err
            cb err

module.exports = config