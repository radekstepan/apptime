module.exports =
    
    # How often to check in minutes.
    timeout: 1
    
    # Email config, see `nodemailer`.
    email:
        fields:
            from: 'Upp Bot <piracy@microsoft.com>'
            to: 'Mailing list <some@domain.uk>'
        smtp:
            host: 'smtp.gmail.com'
            port: 465
            secureConnection: yes
            auth:
                user: 'username@gmail.com'
                pass: 'password'

        # The template of an alert email.
        template:
            subject: 'Status alert: <%- @name %> is <%- @status %>'
            html:
                up: '<%- @name %> is UP again at <%- @time %>, after <%- @since -> of downtime.'
                down: '<%- @name %> is down since <%- @since %>.'
    
    # Commands we can do.
    handlers:

        ping:
            command: 'ping <%- @server %> -c 1', # one request to be sent using `ping`
            success: '1 packets transmitted, 1 received, 0% packet loss, time 0ms' # regex
            # The individual jobs we want to run.
            jobs:
                'web0':
                    server: 'web0'
                'InterMine Labs':
                    server: 'ukraine'

        httping:
            command: 'httping <%- @url %> -c 1'
            success: '1 connects, 1 ok, 0.00% failed'
            jobs:
                'FlyMine Beta':
                    url: 'http://beta.flymine.org'