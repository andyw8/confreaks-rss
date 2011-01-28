Url = require('url')
Sys = require('sys')
Express = require('express')
Helpers = require('./helpers.js')

Promise = (func, args...) ->
  continuable = Continuables.create()
  args.push (response) ->
    continuable.fulfill(response)
  func.apply this, args
  continuable

app = Express.createServer()

app.get '/:conf/:size', (req, res) ->
  res.contentType('application/rss+xml')
  Helpers.videoRssForConference req.params.conf, req.params.size, (xml) ->
    res.send(xml)

app.listen(7070)