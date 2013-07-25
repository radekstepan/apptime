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

# Functionalize templates.
_.assign config.email.templates, config.email.templates, (tml) ->
    (context={}) ->
        eco.render tml, context

# Open db.
jb = EJDB.open dir + '/db/upp.ejdb'

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

        # Get previous status (us reverse ordered by timestamp and only 1).
        async.parallel [ (cb) ->
            jb.findOne 'status', me
            , $orderby:
                time: -1
            , (err, obj) ->
                previous = obj ; cb err

        # Get current status by execing a command.
        , (cb) ->
            # Exec command in current dir.
            exec "cd #{dir}/scripts/ ; #{command}", (err, stdout, stderr) ->
                # No is the default.
                return cb null if err or stderr

                # Did it work?
                try
                    result = success.test stdout
                catch err
                    return cb "Problem running regex `#{success}`"

                # The new status.
                current.up = result

                cb null

        ], (err) ->
            cb err

    # Save latest UP or DOWN status w/ timestamp.
    , (cb) ->
        jb.update 'latest', { $upsert: _.extend(me, current) }, me, (err, updated) -> cb err

    # Determine what has happened.
    , (cb) ->

        # Log it.
        status = [ 'UP', 'DOWN' ][+!current.up]
        log.inf "#{name} is #{status} (#{handler})"

        # ----------------------------------

        # Nice date formatter.
        dater = (int) ->
            moment(new Date(int)).format('HH:mm:ss on ddd')

        # Message about a downtime starting at this time.
        messageDowntime = (time) ->
            (cb) ->
                try
                    console.log
                        subject: config.email.templates.subject { name: name, status: 'DOWN' }
                        html: config.email.templates.down { name: name, since: dater(time) }
                catch err
                    return cb err
        
        # Message about a service coming back UP.
        messageDiff = (timeA, timeB) ->
            (cb) ->
                cb null

        # Start a downtime event of 1 ms.
        initDowntime = (time, length=1) ->
            (cb) ->
                cb null

        # Add a time to a downtime event for timeA day.
        addDowntime = (timeA, timeB) ->
            (cb) ->
                cb null
        
        # ----------------------------------

        # If no previous or was UP.
        if _.isNull(previous) or previous.up is yes
            # If we are now DOWN
            if current.up is no
                async.parallel [
                    # Message about the time since current.
                    messageDowntime(current.time)
                    # Init 1 ms downtime for today (so we have a non zero total number).
                    initDowntime current.time
                ], cb

        # If we were DOWN.
        else
            # Message about the total diff if we currently up?
            async.waterfall [ (cb) ->
                return cb null if current.up is no
                do messageDiff(previous.time, current.time) cb

            # We are currently down.
            , (cb) ->
                # If previous was yesterday?
                if previous.time < startOfToday
                    async.parallel [
                        # Add downtime ms to yesterday counter.
                        addDowntime(previous.time, startOfToday)
                        # Add downtime ms to today counter.
                        addDowntime(startOfToday, current.time)
                    ], cb
                
                # Else previous must be today.
                else
                    # Add downtime ms to today counter.
                    do addDowntime(previous.time, current.time) cb

            ], cb


        return

        # ----------------------------------

        # Db update.
        jb.update 'status', { $upsert: _.extend(me, current) }, me, (err, updated) -> cb err

        # Determine the downtime.
        diff = moment(current.time).diff(moment(previous.time), 'minutes')

        # Save the event too.
        jb.save 'events', me(
            time: current.time
            text: tmls[status.toLowerCase()]
            status: status
        ), cb

        # TODO Mail it!

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

# All jobs in parallel...
q = async.queue (noop, done) ->
    log.dbg 'Running'
    errors = [] # clear all previous errors
    async.each jobs, one, done
, 1 # ... with concurrency of 1...

# ...now.
do run = _.bind q.push, null, {} # passing array to q.push != one job

# ... and in the future.
interval = setInterval run, config.timeout * 6e4

# Handle an HTTP request.
respond = (files, res) -> # these are not the Droids blah blah...
    # When does today end? Cutoff on 7 days before that.
    cutoff = moment((new Date()).setHours(23,59,59,999)).subtract('days', 7)

    days = []

    # Any errors awaiting for us?
    async.waterfall [ (cb) ->
        return cb null if !errors.length
        cb errors
    
    # Find all the events.
    , (cb) ->
        jb.find 'events',
            time:
                $gt: +cutoff
        ,
            $orderby:
                time: 1
        , (err, cursor, count) ->
            return cb err if err

            data = []
            while cursor.next()
                data.push cursor.object()

            cb null, data

    # Classify each day in the past week.
    , (events, cb) ->
        # Init the 7 bands as unknowns (or maybe we don't have the data) for each current config.
        bands = {}
        for job in jobs
            bands[job.handler] ?= {}
            bands[job.handler][job.name] = ( [] for i in [0...7] )

        # Sliding window biz.
        for band in [0...7]
            # Increase the cutoff to the end of the day.
            cutoff = cutoff.add('days', 1)

            # Go through all events below the cutoff.
            length = 0
            for event in events when event.time < cutoff
                length += 1 # we will remove this many
                bands[event.handler][event.name][band].push event

            # Remove them from the original pile.
            events = events.slice length

            # Save for the renderer.
            days.push cutoff.format('ddd D/M').split(' ')

        # Return.
        cb null, eco.render files['index.eco'],
            bands: bands
            css: files['normalize.css'] + '\n' + files['app.styl']
            days: days

    ], (err, html) ->
        # JSON bad
        if err
            res.writeHead 500, 'content-type': 'application/json'
            res.write JSON.stringify error: err
            res.end()

        # HTML good
        else
            res.writeHead 200, 'content-type': 'text/html'
            res.write html
            res.end()

# Start flatiron dash app.
app = flatiron.app
app.use flatiron.plugins.http

# Toor.
app.router.path '/', ->
    @get -> respond @res # this one is already partially applied!

# Load all the files.
async.map filenames = [ 'index.eco', 'app.styl', 'normalize.css' ], (filename, cb) ->
    fs.readFile dir + '/src/dashboard/' + filename, 'utf-8', (err, data) ->
        return cb err if err
        # Not Stylus is it?
        if filename.match /\.styl$/
            stylus(data).set('compress', true).render cb
        else
            cb null, data

, (err, mapped) ->
    throw err if err

    # Partially apply our processed files.
    respond = _.partial respond, _.object filenames, mapped

    # Blast off.
    app.start process.env.PORT, (err) ->
        log.dbg 'upp'.bold + ' dashboard online'
        throw err if err