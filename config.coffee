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
                'web0':
                    server: 'web0'
                'ukraine':
                    server: 'ukraine.sysbiol.cam.ac.uk'

        httping:
            command: 'httping <%- @url %> -c 1 -s'
            success: '1 connects, 1 ok, 0.00% failed'
            jobs:
                'beta.flymine.org':
                    url: 'http://beta.flymine.org'

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
                'intermine (github)':
                    repo: 'git://github.com/intermine/intermine.git'

# InterMine specific config @ukraine.
return module.exports = require './config.intermine.coffee' if process.env.INTERMINE is '1'