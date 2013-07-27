#!/usr/bin/env coffee
{ _ } = require 'lodash'
eco   = require 'eco'

# Already resolved earlier config.
config = require './config.coffee'

# Make an array of jobs to run.
jobs = []
for handler, value of config.handlers
    for name, opts of value.jobs
        obj = _.extend _.clone(value), name: name, handler: handler
        obj.success ?= /[\s\S]*/ # optional, always pass
        # Make it into regex if it is not one already.
        obj.success = new RegExp obj.success unless _.isRegExp obj.success
        obj.command = eco.render obj.command, opts
        # Clean & push.
        delete obj.jobs
        jobs.push obj

module.exports = jobs