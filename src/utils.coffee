#!/usr/bin/env coffee
{ _ } = require 'lodash'

# Already resolved earlier jobs.
jobs = require './jobs.coffee'

# Filter an array from db to a known one.
exports.known = (arr) ->
    _.filter arr, (a) ->
        # Find the entry in the existing ones.
        _.find jobs, (b) ->
            a.handler is b.handler and a.name is b.name

# Arrayize results (from db).
exports.arrayize = (cb, err, cursor, count) ->
    return cb err if err

    # Any results at all?
    return ( cursor.close() ; cb(null, []) ) if !count
    # Get the array.
    cb null, ( cursor.object() while cursor.next() )
    cursor.close()