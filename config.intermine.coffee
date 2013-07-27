module.exports =
    
    # How often to check (in minutes).
    timeout: 1
    
    # Email config, see `nodemailer`.
    email:
        # Do we want to send emails?
        active: yes

        # See `nodemailer` for config.
        fields:
            from: 'apptime bot <flymine.org@gmail.com>'
            to: 'Radek <radek.stepan@gmail.com>'
        smtp:
            host: 'smtp.gmail.com'
            port: 465
            secureConnection: yes
            auth:
                user: 'flymine.org@gmail.com'
                pass: process.env.PASSWORD

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
                'web0 (apache)':
                    server: 'web0'
                'prod1 (production)':
                    server: 'prod1'
                'prod2 (dev)':
                    server: 'prod2'
                'met0 (production)':
                    server: 'met0'
                'met1 (build)':
                    server: 'met1'
                'modprod0 (production)':
                    server: 'modprod0'
                'modprod1 (build)':
                    server: 'modprod1'
                'fileserver2 (home)':
                    server: 'fileserver2'
                'fileserver3 (home)':
                    server: 'fileserver3'
                'ukraine (machine)':
                    server: 'ukraine'
                'ukraine (paas)':
                    server: 'ukraine'
                'newvegas (radek)':
                    server: 'newvegas'
                'kermit (julie)':
                    server: 'kermit'
                'squirrel (alex)':
                    server: 'squirrel'

        httping:
            command: 'httping <%- @url %> -c 1 -s'
            success: '1 connects, 1 ok, 0.00% failed'
            jobs:
                'cdn':
                    url: 'http://cdn.intermine.org'
                'away calendar':
                    url: 'http://php.intermine.org'
                'beta flymine':
                    url: 'http://beta.flymine.org'
                'flymine':
                    url: 'http://www.flymine.org'
                'metabolicmine':
                    url: 'http://metabolicmine.org/beta/begin.do'
                'modencode':
                    url: 'http://modencode.org'
                'modmine':
                    url: 'http://intermine.modencode.org'
                'intermod':
                    url: 'http://www.crossmodel.org'
                'micklemlab':
                    url: 'http://www.micklemlab.org'
                'steps':
                    url: 'http://steps.intermine.org'
                'api docs':
                    url: 'http://iodocs.labs.intermine.org'
                'accordb':
                    url: 'http://accordb.intermine.org'
                'github notifier':
                    url: 'http://github-notify.labs.intermine.org'
                'apps/a (demo)':
                    url: 'http://report-widgets.labs.intermine.org'
                'intermine.org':
                    url: 'http://intermine.github.io/intermine.org'
                'intermine docs':
                    url: 'http://intermine.readthedocs.org/en/latest'

        git:
            command: 'git ls-remote <%- @repo %>'
            success: 'refs/heads/master'
            jobs:
                'intermine (github)':
                    repo: 'git://github.com/intermine/intermine.git'