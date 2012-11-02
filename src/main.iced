
crypto = require 'crypto'
qs = require 'querystring'
request = require 'request'
xml = require 'xml2js'
url = require 'url'

##=======================================================================

exports.Connection = class Connection

  #-------------------------------

  constructor : ({@accessKeyId, @secretAccessKey, @awsHost}) ->
    @awsHost = 'queue.amazonaws.com' unless @awsHost

  #-------------------------------

  createTopic : ({owner, topic}) ->
    return new Topic { conn : @, owner, topic }

##=======================================================================

class Topic 

  #-------------------------------

  constructor : ({@conn, @owner, @topic}) ->

  #-------------------------------

  makeCall : (command) ->
    return new Call { topic : @, command }
    
  #-------------------------------

  receiveMessage : (cb) ->
    q =
      Action: 'ReceiveMessage'
      AttributeNAme : "All"
      MaxNumberOfMessages : 5
      VisbilityTimeout : 15
      Version : "2011-10-01"
    call = @makeCall q
    await call.run defer err, res
    cb err, res
  
##=======================================================================

class Call
  
  #-------------------------------

  constructor : (@topic, @command) ->
 
  #-------------------------------

  hmac : (str) ->
    console.log "secret access key: #{@secretAccessKey}"
    hash = crypto.createHmac 'sha256', @topic.conn.secretAccessKey
    return hash.update(str).digest('base64')

  #-------------------------------

  makeTime : (o) ->
    fmt = (d) -> if d < 10 then "0#{d}" else d
    mon = fmt(o.getUTCMonth() + 1)
    day = fmt o.getUTCDate()
    year = o.getUTCFullYear()
    date = [ year, mon, day].join "-"
    tparts = for x in [o.getUTCHours(), o.getUTCMinutes(), o.getUTCSeconds()]
      fmt x
    time = tparts.join ":"
    return #{date}T#{time}Z"
  
  #-------------------------------

  makeAuth : (now, pairs) ->
    auth_pairs = [ [ "AWSAccessKeyId", @accessKeyId ],
             [ "Algorithm", "HmacSHA256" ],
             [ "Signature", @hmac now ] ]

    auth = "AWS3-HTTPS " + ( v.join "=" for v in auth_pairs).join ","
    return auth

  #-------------------------------

  makeHeaders : ({now, body, auth}) ->
    headers = 
      'Date' : now
      'Host': @awsHost
      'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'
      'Content-Length': body.length
      'X-Amzn-Authorization': auth
    return headers
 
  #-------------------------------

  run : (cb ) ->
    pathname =  [ @topic.owner, @topic.owner ].join "/"
    now = (new Date()).toUTCString()
    body = qs.stringify @command
    auth = @makeAuth now
    headers = @makeHeaders { now , body, auth }

    uri = url.format
      host : @topic.conn.awsHost,
      pathname,
      protocol : "https"
      
    console.log "calling to #{uri}"
    
    req = 
      method: 'POST'
      uri: uri
      headers: headers
      body: body

    console.log "Headers: #{JSON.stringify req}"

    await request req, defer err, response, body
    data = null
    if not err? and body?
      parser = new xml.Parser
      await parser.parseString body, defer err, data
      if data.hasOwnProperty 'Error'
        err = new Error data.Error.Message
        
    cb err, data

  #-------------------------------

##=======================================================================
