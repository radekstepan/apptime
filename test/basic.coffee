#!/usr/bin/env coffee
assert  = require 'assert'
proxy   = require 'proxyquire'
{ _ }   = require 'lodash'
path    = require 'path'

root = path.resolve __dirname, '../'

module.exports =  
    'Start to UP': (done) ->
        apptime = proxy root + '/src/main.coffee',
            './job.coffee': (opts, cb) ->
                process.nextTick cb
        
        apptime.call null

    # 'Start to DOWN': (done) ->
    #     done()

    # 'UP to UP': (done) ->
    #     done()

    # 'DOWN to DOWN': (done) ->
    #     done()

    # 'UP to DOWN': (done) ->
    #     done()

    # 'DOWN to UP': (done) ->
    #     done()