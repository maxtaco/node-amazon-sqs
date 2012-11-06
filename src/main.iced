
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

  makeAuthenticatedRestCall : (command) ->
    return new AuthenticatedRestCall { topic : @, command }
    
  #-------------------------------

  _doCall : (q, cb) ->
    arc = @makeAuthenticatedRestCall q
    arc.run cb
   
  #-------------------------------

  receiveMessage : (cb) ->
    q =
      Action: 'ReceiveMessage'
      AttributeName : "All"
      MaxNumberOfMessages : 5
      VisbilityTimeout : 15
    @_doCall q, cb
    
  #-------------------------------

  deleteMessage : (rh, cb) ->
    q =
      Action: 'DeleteMessage'
      ReceiptHandle : rh
    @_doCall q, cb
  
##=======================================================================

class AuthenticatedRestCall
  
  #-------------------------------

  constructor : ({@topic, @command}) ->
    @version = "2011-10-01"
    @search = ""
 
  #-------------------------------

  hmac : (str) ->
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
    return "#{date}T#{time}Z"
  
  #-------------------------------

  toList : (d) -> out = ([ qs.escape(k), qs.escape(v) ] for k,v of d)

  #-------------------------------

  addParams : (list) ->
    s = (pair.join "=" for pair in list).join "&"
    @search += "&" if @search.length
    @search += s
    
  #-------------------------------
  
  makeParams : () ->
    boiler_plate =
      SignatureMethod : "HmacSHA256"
      SignatureVersion : 2
      Timestamp : @now
      Version : @version
      AWSAccessKeyId : @topic.conn.accessKeyId
    list = (@toList boiler_plate).concat @toList @command
    list.sort()
    @addParams list
  
  #-------------------------------

  signCall : () ->
    input =  [
      @method
      @host
      @pathname
      @search
      ].join "\n"
    sig = @hmac input
    @addParams @toList { Signature : sig }
   
  #-------------------------------

  run : (cb) ->
    @method = "GET"
    @protocol = "https"
    @host = @topic.conn.awsHost
    @pathname =  [ '', @topic.owner, @topic.topic ].join "/"
    @now = @makeTime new Date()
    
    @makeParams()
    @signCall()

    uri = url.format { @host, @pathname, @protocol, @search }
      
    req = 
      method: @method
      uri: uri

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
