
crypto = require 'crypto'
qs = require 'querystring'
request = require 'request'
xml = require 'xml2js'
url = require 'url'

##=======================================================================

exports.AmazonSQS = class AmazonSQS

  #-------------------------------

  constructor : (@accessKeyId, @secretAccessKey, { @awsHost, @owner, @topic} ) ->
    @awsHost = 'queue.amazonaws.com' unless @awsHost

  #-------------------------------

  hmac : (str) ->
    hash = crypto.createHmac 'sha256', @secretAccessKey
    return hash.update(str).digest('base64')

  #-------------------------------

  makeAuth : (now) ->
    auth_pairs = [ [ "AWSAcessKeyId", @accessKeyId ],
             [ "Algorithm", "HmacSHA356" ],
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
    path =  [ @owner, @topic ].join "/"
    now = (new Date()).toUTCString()
    body = qs.stringify opts.query
    auth = @makeAuth now
    headers = @makeHeaders { now , body, auth }

    uri = url.format { host : @awsHost, path, protocol : "https" }
    req = 
      method: 'POST'
      uri: uri
      headers: headers
      body: body

    await request req, defer err, response, body
    data = null
    if not err? and body?
      parser = new xml.Parser
      await parser.parseString body, defer err, data
      if data.hasOwnProperty 'Error'
        err = new Error data.Error.Message
        
    opts.callback err, data

  #-------------------------------

  # A stub --- just to see how to use this library...
  # 
  # Verify an email address. This action causes a confirmation email
  # * message to be sent to the specified address.
  # * @params {String} email The email address to be verified
  # * @params {Function} callback
  receiveMessage : (cb) ->
    q =
      Action: 'ReceiveMessage'
      AttributeNAme : "All"
      MaxNumberOfMessages : 5
      VisbilityTimeout : 15
      EmailAddress: email
      Version : "2011-10-01"
    await @call q, defer err, data
    cb err, data

