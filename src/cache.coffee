#!/usr/bin/env coffee
{ _ } = require 'lodash'

# A little sockpuppet for caching data to display on api.
cache = null
errors = []

exports.clear = ->
    cache = null ; errors = []
exports.save = (obj) ->
    cache = obj
exports.get = ->
    cache

exports.error = (obj) ->
    errors.push obj
exports.getErrors = ->
    errors