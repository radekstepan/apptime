class exports.App

    constructor: (config, @templates) ->

    render: (target) ->
        $.getJSON 'api', (data) =>
            $(target).html @templates['app.eco'] _.extend data,
                # Minute formatter.
                toMinutes: _.memoize (seconds) ->
                    Math.ceil seconds / 60