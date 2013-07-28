#!/usr/bin/env coffee
path       = require 'path'
{ _ }      = require 'lodash'
async      = require 'async'
{ exec }   = require 'child_process'
log        = require 'node-logging'
moment     = require 'moment'

# Root dir.
dir = path.resolve __dirname, '../'

cache  = require './cache.coffee'  # save to display next
config = require './config.coffee' # config
jb     = require './db.coffee'     # db handle
date   = require './date.coffee'   # date utilities
mailer = require './mailer.coffee' # mailer

# If errors happen during a job, save them in the cache.
log.err = _.wrap log.err, (fn, message) ->
    # Log.
    fn message
    # Save.
    cache.error message.toString()

# Process one job.
exports.one = ({ handler, name, command, success }, done) ->
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
                        since: date.format time, 'ddd, HH:mm:ss'
                ], (err, email) ->
                    return cb err if err
                    # Mail it.
                    mailer email, cb
        
        # Message about a service coming back UP.
        messageDiff = (timeA, timeB) ->
            (cb) ->
                async.parallel [
                    _.partial config.email.templates.subject, { name: name, verb: 'is', status: 'UP' }
                    _.partial config.email.templates.up,
                        name: name
                        time: date.format timeB, 'ddd, HH:mm:ss'
                        diff: moment.duration(timeB - timeA).humanize()
                ], (err, email) ->
                    return cb err if err
                    # Mail it.
                    mailer email, cb

        # Start a downtime event of 1s, maybe.
        initDowntime = (time, length=1) ->
            (cb) ->
                # Which day? Our "id".
                day = date.format time, 'YYYY-MM-DD'

                # If we already have a downtime today...
                jb.update 'downtime', _.extend({}, me,
                    day: day
                    # ...just update our time.
                    $set:
                        time: time
                    # ...otherwise save the whole shebang
                    $upsert: _.extend({}, me,
                        day: day
                        time: time
                        length: length
                    )
                ), (err, updated) ->
                    cb err

        # Add a time to a downtime event for timeA day.
        addDowntime = (timeA, timeB) ->
            (cb) ->
                # An inc update (do not update time!).
                jb.update 'downtime', _.extend({}, me,
                    day: date.format timeA, 'YYYY-MM-DD'
                    $inc:
                        length: moment(timeB).diff(moment(timeA), 'seconds')
                ), (err, updated) ->
                    cb err
        
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
                # Init downtime ms for today.
                initDowntime(startOfToday)
            ], cb

        ], cb

    ], (err) ->
        # Fatal err, just log it :).
        log.err err if err
        # All fine.
        done null