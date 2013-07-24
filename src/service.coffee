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
moment     = require 'moment'
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
        async.waterfall [ (cb) ->
            jb.save 'updates', obj =
                name: name
                command: command
                time: + new Date
                status: if result then 'UP' else 'DOWN'
            , (err) ->
                delete obj.command
                cb err, obj
        
        # Change of status check.
        , (current, cb) ->
            # Log it.
            log.inf "#{name} is #{current.status}"

            # Has the status changed?
            jb.findOne 'status',
                job: current.job
            , (err, previous) ->
                return cb err if err

                # First save?
                return jb.save('status', current, cb) unless previous

                # A change of status?
                # return cb null if previous.status is current.status
                
                # Save & mail then.
                diff = moment(current.time).diff(moment(previous.time), 'minutes')

                async.parallel [ (cb) ->
                    # Save the new status.
                    jb.update 'status',
                        name: name
                        '$set': current
                    , cb

                , (cb) ->
                    # Render all email templates.
                    tmls = _.cloneDeep config.email.template

                    tmls = _.map [ tmls.subject, tmls.html.up, tmls.html.down ], (tml) ->
                        dater = (int) -> moment(new Date(int)).format("ddd, HH:mm:ss")

                        try
                            tml = eco.render tml, _.extend _.clone(current),
                                'diff': diff + 'm' # in minutes
                                'time': dater current.time
                                'since': dater previous.time
                            return tml
                        catch err
                            return cb err

                    console.log tmls

                ], cb

        ], cb

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
        res = @res
        console.log 'HTTP /'

# Startup.
app.start process.env.PORT, (err) ->
    log.inf 'upp'.bold + ' started'
    throw err if err