#!/usr/bin/env coffee
moment = require 'moment'

# Date formatter
exports.format = (int, format) -> moment(new Date(int)).format(format)