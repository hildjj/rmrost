#!/usr/bin/env coffee

xmpp = require 'node-xmpp'

if process.argv.length < 3
    console.log "Usage: #{process.argv[1]} <my-jid> <my-password>"
    process.exit 64

class Tracker
  constructor: (@cli) ->
    @id = 0
    @pending = {}
    @cli.addListener 'rawStanza', (iq) =>
      if (iq.name != 'iq') or (iq.attrs.type not in ['result', 'error'])
        return
      id = iq.id
      cb = @pending[id]
      if cb
        delete @pending[id]
        cb iq

  send: (iq, cb) ->
    i = (iq.id = "track-#{@id++}")
    @pending[i] = cb
    #console.log "C: #{iq.toString()}"
    @cli.send iq

cl = new xmpp.Client
  jid: process.argv[2]
  password: process.argv[3]
t = new Tracker cl

getRoster = (cb) ->
  iq = new xmpp.Iq
    type: 'get'
  iq.c 'query',
    xmlns: 'jabber:iq:roster'
  t.send iq, cb

rmRoster = (jid, cb) ->
  iq = new xmpp.Iq
    type: 'set'
  iq.c 'query',
    xmlns: 'jabber:iq:roster'
  .c 'item',
    jid: jid
    subscription: 'remove'
  t.send iq, cb

gotRoster = (iq) ->
  # make sure we get all of the requests out before starting to be finished
  outstanding = 1

  if iq.attrs.type != 'result'
    console.error 'Roster error'
    return
  console.log 'roster'
  q = iq.getChild 'query', 'jabber:iq:roster'
  for i in q?.getChildren 'item'
    if i.attrs.subscription in ['from', 'none']
      # all of the from's or none's
      console.log i.attrs.jid, i.attrs.subscription
      outstanding++
      rmRoster i.attrs.jid, ->
        outstanding--
        if outstanding <= 0
          process.exit 0
  outstanding--
  # probably didn't find any.  Just quit.
  if outstanding <= 0
    process.exit 0

cl.addListener 'online', ->
  console.log 'online'
  getRoster gotRoster

cl.addListener 'error', (e) ->
  console.error e
  process.exit 1
