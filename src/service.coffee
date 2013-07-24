#!/usr/bin/env coffee
{ _ }      = require 'lodash'
{ exec }   = require 'child_process'
async      = require 'async'
nodemailer = require 'nodemailer'
eco        = require 'eco'
flatiron   = require 'flatiron'
union      = require 'union'
EJDB       = require 'ejdb'
path       = require 'path'
stylus     = require 'stylus'
log        = require 'node-logging'
fs         = _.extend require('fs'), require('fs-extra')

# Root dir.
dir = path.resolve __dirname, '../'

# Read our config file.
config = require dir + '/config.coffee'

# Open db.
jb = EJDB.open dir + '/db/upp.ejdb'

# Process one job.
one = ({ command, success, name }, cb) ->
    # Run it.
    exec command, (err, stdout, stderr) ->
        return cb "Problem runnning `#{command}`" if err or stderr

        # Did it work?
        try
            result = success.test stdout
        catch err
            return cb "Problem running regex `#{success}`"

        # Save the result.
        jb.save 'updates', obj =
            job: name
            command: command
            time: + new Date
            status: if result then 'UP' else 'DOWN'
        
        # Log it.
        log.inf "#{name} is #{obj.status}"

        # Move on.
        cb null

# Make an array of jobs to run (errors will throw and die us).
jobs = []
for handler in _.values config.handlers
    for name, opts of handler.jobs
        obj = _.extend _.clone(handler), name: name
        obj.success = new RegExp obj.success
        obj.command = eco.render obj.command, opts
        delete obj.jobs
        jobs.push obj

# All jobs in parallel, now...
do all = _.bind async.each, null, jobs, one, (err) ->
    log.err err if err # just log them, don't die

# ... and in the future
interval = setInterval all, config.timeout * 6e4

# Start flatiron dash app.
app = flatiron.app
app.use flatiron.plugins.http

# Root.
app.router.path '/', ->
    @get ->
        console.log 'HTTP /'

# Startup.
app.start process.env.PORT, (err) ->
    log.inf 'upp'.bold + ' started'
    throw err if err