request = require 'superagent'
tip     = require 'tip'
_ =
    memoize: require 'memoize'
    extend:  require 'extend'

template = require './template'

module.exports = ->
    request.get '/api', (res) ->
        return document.body.innerHTML = res.text if res.statusType isnt 2

        data = JSON.parse res.text

        document.body.innerHTML = template _.extend data,
            toMinutes: _.memoize (seconds) ->
                Math.ceil(seconds / 60) + 'm'
        
        tip('.tipped')