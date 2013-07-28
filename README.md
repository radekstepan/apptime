#apptime

Server uptime monitoring linked to a mailer. You can run any type of command to check that something is up/down.

![image](https://raw.github.com/radekstepan/apptime/master/example.png)

##Quickstart

```bash
$ sudo apt-get install g++ zlib1g zlib1g-dev autoconf # for ejdb
$ npm install apptime
$ pico /tmp/config.coffee # edit config file
$ PORT=6661 CONFIG=/tmp/config.coffee apptime
```

You can leave the `PORT` empty. If you do not provide a `CONFIG` it will default to the example one in the app directory. The path to `CONFIG` is relative to the app directory unless the path starts with a `/` in which case it is absolute.

##Config

The `.coffee` file (think of it as a JSON file on steroids) exports the following:

#####timeout
How often to monitor the servers (in minutes). Each batch will run in a queue with a concurrency of 1.

#####email.active
Shall we actually send an email? You can still use the web interface.

#####email.fields
For config of these follow instructions at [Nodemailer](https://github.com/andris9/Nodemailer#e-mail-message-fields).

#####email.smtp
For config of these follow instructions at [Nodemailer](https://github.com/andris9/Nodemailer#setting-up-smtp).

#####email.templates
An object with [Eco](https://github.com/sstephenson/eco) templates for building emails to be sent. Use HTML, plaintext is auto-generated.

#####handlers
Each key is a type of a job to run. Just a way to allow you to run monitor the same server in more ways than one.

#####handlers.command
A command to execute. All commands are run relative to the `scripts` directory (of course you can run commands linked to your `/bin` directory).

An `err` or `stderr` on `child_process.exec` of the command means the server is down.

Command uses [Eco](https://github.com/sstephenson/eco) syntax and is passed arguments from `handlers.jobs` (see below).

#####handlers.success
Not required. Can be a string or a `RegExp` that will be used to check if command was succesfull. This happens after we check whether the command throws `err` or `stderr` (see above).

#####handlers.jobs
Keys represent names of servers. The values are arguments to be passed to the commands (see above).

##Client-side app

Install dev dependencies (`component` etc.):

```bash
$ npm install -d
```

Install components:
```bash
$ (cd src/dashboard/app ; ../../../node_modules/.bin/component install)
```

Re-build the sources:
```bash
$ coffee src/dashboard/build.coffee
```