xhr  = require 'xhr'
tip  = require 'tip'
Clip = require 'clipboard-dom'
_ =
    memoize: require 'memoize'
    extend:  require 'extend'
    map:     require 'map'

Clip.swf '/bin/ZeroClipboard.swf'

# Functionalize templates.
[ table, error ] = _.map [ './table', './error' ], (tml) ->
    (context, cb) ->
        try
            cb null, require(tml) context or {}
        catch err
            cb err.message

# On errors.
trouble = (errors) ->
    errors = [ errors ] unless errors instanceof Array
    error errors: errors, (err, html) ->
        throw err if err
        document.body.innerHTML = html

# JSON parse.
parse = (string, cb) ->
    try
        cb null, JSON.parse string
    catch err
        cb trouble err.toString()

module.exports = ->

    xhr '/api', (res) ->
        parse res.response, (err, data) ->
            return trouble err if err

            data = _.extend data,
                toMinutes: _.memoize (seconds) ->
                    Math.ceil(seconds / 60) + 'm'

            table data, (err, html) ->
                return trouble err if err

                document.body.innerHTML = html

                # Tooltips.
                tip('.tipped')

                # Copy to clipboard.
                _.map document.querySelectorAll('.clippy'), (el) -> 
                    clip = new Clip el, el.parentNode
                    clip.on 'complete', (text) -> console.log 'copied text'
                    clip.on 'mousedown', -> clip.text el.title

    , (err) ->
        # See the network response for more details.
        trouble err.message