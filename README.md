node-amazon-sqs
===============

Node interface to Amazon SQS, supports the following actions:

* ReceiveMessages

## Install

```
npm install -g amazon-sqs
```

## Building

```
icake build
```

## Using

```coffeescript
SQS = require 'amazon-sqs'

conn = new SQS.Connection 
  accessKeyId : "your-access-key-id"
  secretAccessKey: "your-secret-access-key"

topic = conn.createTopic
  owner : "numeric-owner-id"
  topic : "topic-name"

topic.receiveMessage (err, data) ->
  console.log "done! Err=#{JSON.stringify err}; data=#{JSON.stringify data}"
```
