#!/usr/bin/env coffee
Builder = require 'component-builder'

{ _ }   = require 'lodash'
async   = require 'async'
path    = require 'path'
fs      = require 'fs'
log     = require 'node-logging'

eco     = require 'eco'
cs      = require 'coffee-script'
stylus  = require 'stylus'

dir = path.resolve __dirname, '../../'

# All the custom handlers that we know of.
handlers =

    scripts:
        eco: (pkg, file, cb) ->
            log.dbg p = pkg.path file
            fs.readFile p, 'utf8', (err, src) ->
                return cb err if err
                try
                    out = "module.exports = #{eco.precompile(src)}"
                catch err
                    return cb err

                name = path.basename(file, '.eco') + '.js'
                pkg.addFile 'scripts', name, out
                pkg.removeFile 'scripts', file

                cb null

        coffee: (pkg, file, cb) ->
            log.dbg p = pkg.path file
            fs.readFile p, 'utf8', (err, src) ->
                return cb err if err
                try
                    out = cs.compile src, 'bare': 'on'
                catch err
                    return cb err

                name = path.basename(file, '.coffee') + '.js'
                pkg.addFile 'scripts', name, out
                pkg.removeFile 'scripts', file

                cb null
    
    styles:
        styl: (pkg, file, cb) ->
            log.dbg p = pkg.path file
            
            async.waterfall [ (cb) ->
                fs.readFile p, 'utf8', cb
            
            , (src, cb) ->
                stylus.render src, cb
            
            , (out, cb) ->
                name = path.basename(file, '.styl') + '.css'
                pkg.addFile 'styles', name, out
                pkg.removeFile 'styles', file
                
                cb null
            
            ], cb

builder = new Builder dir + '/src/dashboard/app'
builder.use (builder) ->

    for hook, obj of handlers then do (hook, obj) ->
        builder.hook "before #{hook}", (pkg, cb) ->
            # Empty?
            return cb(null) unless (files = pkg.config[hook] or []).length
            
            # Map to handlers.
            files = _.map files, (file) ->
                (cb) ->
                    suffix = file.split('.').pop()
                    return fn(pkg, file, cb) if fn = obj[suffix]
                    cb null
            
            # And exec in series (why!?).
            async.series files, (err) ->
                cb err

# Build.
async.waterfall [ (cb) ->
    builder.build (err, res) ->
        cb err, res

# Write.
, (res, cb) ->
    async.parallel [
        _.partial fs.writeFile, dir + '/public/build.js', res.require + res.js
        _.partial fs.writeFile, dir + '/public/build.css', res.css
    ], cb

# Done.
], (err) ->
    throw err if err
    log.inf 'Done'.bold