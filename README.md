#apptime

Server uptime monitoring linked to a mailer. You can run any type of command to check that something is up/down.

![image](https://raw.github.com/radekstepan/apptime/master/example.png)

##Quickstart

```bash
$ sudo apt-get install g++ zlib1g zlib1g-dev autoconf
$ npm install apptime
```

Edit the `config.coffee` file:

#####timeout
How often monitor the servers (in minutes).

#####email.active
Shall we actually send an email?

#####email.fields
For config of these follow instructions at [Nodemailer](https://github.com/andris9/Nodemailer#e-mail-message-fields).

#####email.smtp
For config of these follow instructions at [Nodemailer](https://github.com/andris9/Nodemailer#setting-up-smtp).

#####email.templates
An object with two [Eco](https://github.com/sstephenson/eco) templates for building emails to be sent. Plaintext is auto-generated from the HTML version.

#####handlers
Each key is a type of a job to run. Just to differentiate that a different command can be run on the same server.

#####handlers.command
A command to execute. All commands are run relative to the `scripts` directory. An err or stderr on child_process.exec of the command means the host/website is down. Additionally, a `success` regex can be provided for each handler that, failing to test for our `stdout`, fails as well.

Command uses [Eco](https://github.com/sstephenson/eco) syntax and is passed arguments from `handlers.jobs` (see below).

#####handlers.success
Not required. Can be a string or a `RegExp` that will be used to check if command was succesfull. This happens after we check whether the command throws `err` or `stderr` (see above).

#####handlers.jobs
Keys represent names of servers for example. The values are arguments to be passed to the commands (see above).

And finally start it all up:

```bash
$ PORT=6661 node index.js # you can leave port empty
```