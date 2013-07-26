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
connect    = require 'connect' 
middleware = require 'apps-a-middleware'
fs         = _.extend require('fs'), require('fs-extra')

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

# Open db.
jb = EJDB.open dir + '/db/upp.ejdb'

# Date formatter
format = (int, format) -> moment(new Date(int)).format(format)

# If errors happen during a job, save them here so that dash can display them.
errors = []
log.err = _.wrap log.err, (fn, message) ->
    fn message # log it
    errors.push message.toString() # save it

# Process one job.
one = ({ handler, name, command, success }, done) ->
    # Global.
    previous = null ; current = time: + new Date, up: no

    # When does today start? Returns an int.
    startOfToday = (new Date(current.time)).setHours(0,0,0,0)

    # Always save with our info.
    me = { handler: handler, name: name }

    # Get then and now.
    async.waterfall [ (cb) ->

        # Get previous status (and do descending sort on time just to make sure).
        async.parallel [ (cb) ->
            jb.findOne 'latest', me, { $orderby: time: -1 }, (err, obj) ->
                previous = obj ; cb err

        # Get current status by execing a command.
        , (cb) ->
            # Exec command in current dir.
            exec "cd #{dir}/scripts/ ; #{command}", (err, stdout, stderr) ->
                # No is the default.
                return cb null if err or stderr

                # Did it work?
                try
                    current.up = success.test stdout
                catch err
                    return cb "Problem running regex `#{success}`"

                cb null

        ], (err) ->
            cb err

    # Save latest UP or DOWN status w/ timestamp.
    , (cb) ->
        jb.update 'latest',
            _.extend({}, me, $set: current, $upsert: _.extend({}, me, current))
        , (err, updated) ->
            cb err

    # Determine what has happened.
    , (cb) ->
        # Log it.
        status = [ 'UP', 'DOWN' ][+!current.up]
        log.inf "#{name} is #{status} (#{handler})"

        # ----------------------------------

        # Message about a downtime starting at this time.
        messageDowntime = (time) ->
            (cb) ->
                async.parallel [
                    _.partial config.email.templates.subject, { name: name, verb: 'is', status: 'DOWN' }
                    _.partial config.email.templates.down,
                        name: name
                        since: format time, 'ddd, HH:mm:ss'
                ], (err, templates) ->
                    return cb err if err
                    console.log templates
                    cb null
        
        # Message about a service coming back UP.
        messageDiff = (timeA, timeB) ->
            (cb) ->
                async.parallel [
                    _.partial config.email.templates.subject, { name: name, verb: 'is', status: 'UP' }
                    _.partial config.email.templates.up,
                        name: name
                        time: format timeB, 'ddd, HH:mm:ss'
                        diff: moment.duration(timeB - timeA).humanize()
                ], (err, templates) ->
                    return cb err if err
                    console.log templates
                    cb null

        # Start a downtime event of 1s, maybe.
        initDowntime = (time, length=1) ->
            (cb) ->
                # Which day? Our "id".
                day = format time, 'YYYY-MM-DD'

                # Check/save this.
                save = _.extend({}, me, { day: day })

                # Do we have something already?
                async.waterfall [ (cb) ->
                    jb.findOne 'downtime', save, cb

                # If we have an object, we do not need to init.
                , (obj, cb) ->
                    return cb null if obj
                    # Save the first downtime of today boosting with a length.
                    jb.save 'downtime', _.extend(save,
                        length: length
                        time: time # so we can efficiently retrieve a range
                    ), cb

                ], cb

        # Add a time to a downtime event for timeA day.
        addDowntime = (timeA, timeB) ->
            (cb) ->
                # An inc update.
                jb.update 'downtime', _.extend({}, me,
                    day: format timeA, 'YYYY-MM-DD'
                    $inc:
                        length: moment(timeB).diff(moment(timeA), 'seconds')
                ), (err, updated) ->
                    cb null
        
        # ----------- THE LOGIC -----------

        # If no previous or was UP.
        if _.isNull(previous) or previous.up
            # Exit if we are now UP.
            return cb null if current.up
            
            # If we are now DOWN.
            return async.parallel [
                # Message about the time since current.
                messageDowntime(current.time)
                # Init 1 ms downtime for today (so we have a non zero total number).
                initDowntime current.time
            ], cb

        # We were DOWN.
        # Message about the total diff if we are currently UP.
        async.waterfall [ (cb) ->
            return cb null if current.up is no
            messageDiff(previous.time, current.time) cb

        # Add downtime whether we are UP or DOWN now.
        , (cb) ->
            # Is previous today?
            return addDowntime(previous.time, current.time) cb if previous.time > startOfToday

            # Previous must have been yesterday then.
            async.parallel [
                # Add downtime ms to yesterday counter.
                addDowntime(previous.time, startOfToday)
                # Add downtime ms to today counter.
                addDowntime(startOfToday, current.time)
            ], cb

        ], cb

    ], (err) ->
        # Fatal err, just log it :).
        log.err err if err
        # All fine.
        done null

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

# Handle an HTTP request.
respond = (res) ->
    # When does today end? Cutoff on 7 days before that.
    cutoff = moment((new Date()).setHours(23,59,59,999)).subtract('days', 7)

    # Any errors awaiting for us?
    async.waterfall [ (cb) ->
        return cb null if !errors.length
        cb errors
    
    # Find all the events.
    , (cb) ->
        jb.find 'downtime',
            time:
                $gt: +cutoff
        ,
            $orderby:
                time: 1
        , (err, cursor, count) ->
            return cb err if err

            # Any results at all?
            return ( cursor.close() ; cb(null, []) ) if !count
            # Get the array.
            cb null, ( cursor.object() while cursor.next() )
            cursor.close()

    # Classify each day in the past week.
    , (downtimes, cb) ->
        # Init the 7 bands as unknowns (or maybe we don't have the data) for each current config.
        history = {} ; days = []
        for job in jobs
            history[job.handler] ?= {}
            history[job.handler][job.name] = ( 0 for i in [0...7] )

        # Sliding window biz.
        for band in [0...7]
            # Increase the cutoff to the end of the day.
            cutoff = cutoff.add('days', 1)

            # Go through all events below the cutoff.
            length = 0
            for downtime in downtimes when downtime.time < cutoff
                length += 1 # we will remove this many
                history[downtime.handler][downtime.name][band] += downtime.length

            # Remove them from the original pile.
            downtimes = downtimes.slice length

            # Save the day.
            days.push format(cutoff, 'ddd:DD/M').split(':')

        # Return.
        cb null,
            days: days
            history: history

    ], (err, json) ->
        if err
            res.writeHead 500, 'content-type': 'application/json'
            res.write JSON.stringify error: err
        else
            res.writeHead 200, 'content-type': 'application/json'
            res.write JSON.stringify json

        res.end()

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
async.waterfall [ (cb) ->
    app.start process.env.PORT, cb

# Integrity check.
, (cb) ->
    # For all current jobs, get their latest later than cutoff.
    jb.find 'latest',
        # 3m behind last timeout.
        time:
            $lt: + new Date - ( (config.timeout + 3) * 6e4 )
        # Remove them at the same time.
        $dropall: yes
    , cb

# Message if we were down.
, (cursor, count, cb) ->
    return cb null if !count # db is empty

    # Get the array.
    arr = ( cursor.object() while cursor.next() )
    cursor.close()

    # Filter down to jobs we currently know.
    arr = _.filter arr, (a) ->
        # Find the entry in the existing ones.
        _.find jobs, (b) ->
            a.handler is b.handler and a.name is b.name

    return cb null if !arr.length # we did not know any of them

    log.dbg "#{count} jobs are behind schedule"

    # Templatize
    async.parallel [
        _.partial config.email.templates.subject, { name: 'upp process', verb: 'was', status: 'DOWN' }
        _.partial config.email.templates.integrity,
            # Since the latest status update.
            since: format _.max(arr, 'time').time, 'HH:mm:ss on ddd'
    ], (err, templates) ->
        return cb err if err
        console.log templates
        cb null

# Start monitoring.
], (err) ->
    throw err if err
    log.dbg 'upp'.bold + ' dashboard online'

    # All jobs in parallel...
    q = async.queue (noop, done) ->
        log.dbg 'Running a batch'        
        errors = [] # clear all previous errors
        async.each jobs, one, ->
            log.dbg 'Batch done'
            done null
    , 1 # ... with concurrency of 1...

    # ...now.
    do run = _.bind q.push, null, {} # passing array to q.push != one job

    # ... and in the future.
    interval = setInterval run, config.timeout * 6e4