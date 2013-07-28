xhr = require 'xhr'
tip = require 'tip'
_ =
    memoize: require 'memoize'
    extend:  require 'extend'
    map:     require 'map'

[ table, error ] = _.map [ './table', './error' ], require

module.exports = ->
    trouble = (errors) -> document.body.innerHTML = error errors

    xhr '/api', (res) ->
        data = JSON.parse res.response

        document.body.innerHTML = table _.extend data,
            toMinutes: _.memoize (seconds) ->
                Math.ceil(seconds / 60) + 'm'
        
        tip('.tipped')
    
    , (err) ->
        # See the network response for more details.
        trouble errors: [ err.message ]