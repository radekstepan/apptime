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
one = ({ handler, name, command, success }, cb) ->
    # Run it.
    exec command, (err, stdout, stderr) ->
        return cb "Problem runnning `#{command}`" if err or stderr

        # Did it work?
        try
            result = success.test stdout
        catch err
            return cb "Problem running regex `#{success}`"

        #Current result.
        current =
            handler: handler
            name: name
            command: command
            time: + new Date
            up: result
        
        # Change of status check.
        status = [ 'UP', 'DOWN' ][+!result]

        # Log it.
        log.inf "#{name} is #{status} (#{handler})"

        # Has the status changed?
        jb.findOne 'status',
            handler: current.handler
            name: current.name
        , (err, previous) ->
            return cb err if err

            # First save?
            return jb.save('status', current, cb) unless previous

            # A change of status?
            return cb null if previous.up is current.up
            
            # Save & mail then.
            diff = moment(current.time).diff(moment(previous.time), 'minutes')

            # Save the new status and time.
            async.parallel [ (cb) ->
                jb.update 'status',
                    $set:
                        time: current.time
                        up: current.up
                ,
                    handler: handler
                    name: name
                , cb

            # Render all templates, save the event and mail it.
            , (cb) ->
                tmls = {}
                for name, tml of config.email.templates
                    dater = (int) -> moment(new Date(int)).format('ddd, HH:mm:ss')

                    try
                        tmls[name] = eco.render tml, _.extend _.clone(current),
                            'diff': diff + 'm' # in minutes
                            'time': dater current.time
                            'since': dater previous.time
                            'status': status
                    catch err
                        return cb err

                # Save the event too.
                jb.save 'events',
                    handler: current.handler
                    name: current.name
                    time: current.time
                    text: tmls[status.toLowerCase()]
                    status: status
                , cb

                # TODO Mail it!

            ], cb

# Make an array of jobs to run (errors will throw and die us).
jobs = [] ; names = []
for handler, value of config.handlers
    for name, opts of value.jobs
        obj = _.extend _.clone(value), name: name, handler: handler
        obj.success = new RegExp obj.success
        obj.command = eco.render obj.command, opts
        delete obj.jobs
        jobs.push obj

# All jobs in parallel, now...
do all = _.bind async.each, null, jobs, one, (err) ->
    log.err err if err # just log them, don't die

# ... and in the future
interval = setInterval all, config.timeout * 6e4

# Handle an HTTP request.
respond = (files, res) -> # these are not the Droids blah blah...
    # When does today end? Cutoff on 7 days before that.
    cutoff = moment((new Date()).setHours(23,59,59,999)).subtract('days', 7)

    days = []

    # Find all the events.
    async.waterfall [ (cb) ->
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
            # Increase the cutoff.
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
        log.inf 'upp'.bold + ' dashboard online'
        throw err if err