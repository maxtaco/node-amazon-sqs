
crypto = require 'crypto'
qs = require 'querystring'
request = require 'request'
xml = require 'xml2js'
url = require 'url'

##=======================================================================

exports.SQS = class SQS

  #-------------------------------

  constructor : ({@accessKeyId, @secretAccessKey, @awsHost, @owner, @topic} ) ->
    @awsHost = 'queue.amazonaws.com' unless @awsHost

  #-------------------------------

  hmac : (str) ->
    console.log "secret access key: #{@secretAccessKey}"
    hash = crypto.createHmac 'sha256', @secretAccessKey
    return hash.update(str).digest('base64')

  #-------------------------------

  makeAuth : (now) ->
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

  call : (query, callback) ->
    pathname =  [ @owner, @topic ].join "/"
    now = (new Date()).toUTCString()
    body = qs.stringify query
    auth = @makeAuth now
    headers = @makeHeaders { now , body, auth }

    uri = url.format { host : @awsHost, pathname, protocol : "https" }
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
        
    callback err, data

  #-------------------------------

  receiveMessage : (cb) ->
    q =
      Action: 'ReceiveMessage'
      AttributeNAme : "All"
      MaxNumberOfMessages : 5
      VisbilityTimeout : 15
      Version : "2011-10-01"
    await @call q, defer err, data
    cb err, data

