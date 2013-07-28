#!/usr/bin/env coffee
module.exports =
    
    # How often to check (in minutes).
    timeout: 1
    
    # Email config, see `nodemailer`.
    email:
        # Do we want to send emails?
        active: no

        # See `nodemailer` for config.
        fields:
            from: 'apptime bot <piracy@microsoft.com>'
            to: 'Mailing list <some@domain.uk>'
        smtp:
            host: 'smtp.gmail.com'
            port: 465
            secureConnection: yes
            auth:
                user: 'username@gmail.com'
                pass: 'password'

        # The template of an alert email.
        templates:
            subject: 'Status alert: <%- @name %> <%- @verb %> <%- @status %>'
            up: '<code><%- @name %></code> is UP again on <%- @time %> after <strong><%- @diff %></strong> of downtime.'
            down: '<code><%- @name %></code> is DOWN since <%- @since %>.'
            integrity: '<pre>apptime</code> process was DOWN since at least <%- @since %>.\n<em>The next batch of messages (if any) may not be true.</em>'
    
    # Commands we can do.
    handlers:

        ping:
            command: 'ping <%- @server %> -c 1', # one request to be sent using `ping`
            success: '1 packets transmitted, 1 received, 0% packet loss, time 0ms' # regex
            # The individual jobs we want to run.
            jobs:
                'localhost':
                    server: 'localhost'

        httping:
            command: 'httping <%- @url %> -c 1 -s -o 100,101,102,200,201,202,203,204,206,300,301,302,303,304,305,307'
            success: '1 connects, 1 ok, 0.00% failed'
            jobs:
                'google':
                    url: 'http://google.org'

        # An example of a running bash scripts.
        bash:
            command: 'bash ./<%- @script %>.sh'
            jobs:
                'unpredictable':
                    script: 'random'
                'offline':
                    script: 'down'

        git:
            command: 'git ls-remote <%- @repo %>'
            success: 'refs/heads/master'
            jobs:
                'apptime (github)':
                    repo: 'git://github.com/radekstepan/apptime.git'