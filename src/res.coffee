#!/usr/bin/env coffee
{ _ }  = require 'lodash'
moment = require 'moment'
async  = require 'async'

utils      = require './utils.coffee' # utilities
{ errors } = require './job.coffee'   # run one job
jb         = require './db.coffee'    # db handle
jobs       = require './jobs.coffee'  # jobs to run from config
date       = require './date.coffee'  # date utilities

# Handle an HTTP request.
module.exports = (res) ->
    # When does today end? Cutoff on 7 days before that.
    cutoff = moment((new Date()).setHours(23,59,59,999)).subtract('days', 7)

    # Any errors awaiting for us?
    async.waterfall [ (cb) ->
        err = errors()
        return cb null if !err.length
        cb err
    
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
        for { handler, name } in jobs
            data[handler] ?= {}
            data[handler][name] =
                latest: map[handler]?[name]
                history: ( 0 for i in [0...7] )

        # Sliding window biz.
        for band in [0...7]
            # Increase the cutoff to the end of the day.
            cutoff = cutoff.add('days', 1)

            # Go through all events below the cutoff.
            l = 0
            for { handler, name, length, time } in downtimes when time < cutoff
                l += 1 # we will remove this many
                data[handler]?[name].history[band] += length

            # Remove them from the original pile.
            downtimes = downtimes.slice l

            # Save the day.
            days.push date.format(cutoff, 'ddd:DD/M').split(':')

        # Return.
        cb null,
            days: days
            data: data
            up: allUp

    ], (err, json) ->
        _.extend(json ?= {}, errors: if _.isArray(err) then err else [ err.toString() ]) if err

        res.writeHead 200, 'content-type': 'application/json'
        res.write JSON.stringify json

        res.end()