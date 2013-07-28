#!/usr/bin/env coffee
{ _ }  = require 'lodash'
moment = require 'moment'
async  = require 'async'
log    = require 'node-logging'

cache = require './cache.coffee' # save to display next
utils = require './utils.coffee' # utilities
jb    = require './db.coffee'    # db handle
jobs  = require './jobs.coffee'  # jobs to run from config
date  = require './date.coffee'  # date utilities

respond = (res, err, json) ->
    # Oopsy Daisy?
    if err
        res.writeHead 500, 'content-type': 'application/json'
        res.write JSON.stringify errors: ( if _.isArray(err) then err else [ err.toString() ] )
    else
        # Cache it.
        cache.save json
        res.writeHead 200, 'content-type': 'application/json'
        res.write JSON.stringify json
    
    res.end()

# Handle an HTTP request.
module.exports = (res) ->
    # Skip?
    return respond res, null, json if json = cache.get()

    log.dbg 'Cold cache'

    # When does today end? Cutoff on 7 days before that.
    cutoff = moment((new Date()).setHours(23,59,59,999)).subtract('days', 7)

    # Any errors awaiting for us?
    async.waterfall [ (cb) ->
        return cb errors if (errors = cache.getErrors()).length
        cb null
    
    , (cb) ->
        # Find all the events.
        async.parallel [ (cb) ->
            jb.find 'downtime',
                time:
                    $gt: +cutoff
            ,
                $orderby:
                    time: 1 # upward
            , _.partial utils.arrayize, cb

        # And also the latest statei.
        , (cb) ->
            jb.find 'latest', {},
                $orderby:
                    time: -1 # downward
            , _.partial utils.arrayize, cb

        ], cb

    # Classify each day in the past week.
    , (arrs, cb) ->
        # Filter the collections to known jobs, sigh.
        [ downtimes, latest ] = ( utils.known arr for arr in arrs )

        # Are all servers up?
        allUp = yes

        # Make the latest info into a unique map (if there are dupes).
        map = {}
        for { handler, name, up, time } in latest
            map[handler] ?= {}
            map[handler][name] ?= { up: up, time: time }
            # Bad server?
            allUp = no if allUp and not map[handler][name].up

        # Init the 7 bands as unknowns (or maybe we don't have the data) for each current config.
        data = {} ; days = []
        for { handler, name, command } in jobs
            data[handler] ?= {}
            data[handler][name] =
                latest: map[handler]?[name]
                history: ( 0 for i in [0...7] )
                command: command

        # Sliding window biz.
        for band in [0...7]
            # Increase the cutoff to the end of the day.
            cutoff = cutoff.add('days', 1)

            # Go through all events below the cutoff.
            l = 0
            for { handler, name, length, time } in downtimes when time < cutoff
                l += 1 # we will remove this many
                data[handler]?[name].history[band] += length
                # Is this the latest downtime for a down machine?
                data[handler][name].latest.since = time unless data[handler][name].latest.up

            # Remove them from the original pile.
            downtimes = downtimes.slice l

            # Save the day.
            days.push date.format(cutoff, 'ddd:DD/M').split(':')

        # Sort by down status, name and handler.
        arr = []
        for handler, names of data
            for name, obj of names
                arr.push _.extend obj,
                    handler: handler
                    name: name
        arr.sort (a, b) ->
            return n if n = +a.latest.up - +b.latest.up # down first
            return n if n = a.name.localeCompare b.name # name alpha
            return n if n = a.handler.localeCompare b.handler.localeCompare # handler alpha
            return 0 # won't happen...

        # Return.
        cb null,
            days: days
            data: arr
            up: allUp

    ], _.partial respond, res