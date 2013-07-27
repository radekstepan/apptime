#!/usr/bin/env coffee
{ _ }      = require 'lodash'
log        = require 'node-logging'
nodemailer = require 'nodemailer'

# Already resolved earlier config.
config = require './config.coffee'

# SMTP mailer or nothing.
module.exports = _.partial (transport, [ subject, body ], cb) ->
    # Do we want it on?
    return cb null unless config.email.active

    fields =
        generateTextFromHTML: yes
        subject: subject
        html: body

    log.dbg 'Sending email'

    # Merge the fields from config onto our generated fields & send.
    transport.sendMail _.extend(fields, config.email.fields), (err) -> cb err
, nodemailer.createTransport 'SMTP', config.email.smtp