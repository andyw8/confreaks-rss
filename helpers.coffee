Sys = require('sys')
YQL = require('yql')
Promise = require('./promised-io/lib/promise')

Root = 'http://confreaks.net'

String.prototype.clean = -> this.replace(/\s+/, ' ')

promiseYQL = (query) ->
  defer = new Promise.defer()
  YQL.exec query, (response) -> defer.resolve(response)
  defer

getUrl = (item) ->
  try
    "#{Root}#{item.a[1].href.split('?')[0]}"
  catch boom
    null

getLength = (item) ->
  try
    item.a[1].content.split(' - ')[3]
  catch boom
    '00:00'

getAuthor = (item) ->
  try
    item.a[0].content.clean()
  catch boom
    'Unknown'

makeRss = (item) ->
  [author, url, length] = [getAuthor(item), getUrl(item), getLength(item)]
  if url?
    "
    <item>
      <title>#{item.p.clean()} - #{author}</title>
      <author>#{author}</author>
      <guid>#{url}</guid>
      <pubDate>#{item.strong}</pubDate>
      <enclosure url='#{url}' length='#{length}' type='video/mp4' />
    </item>
    "
  else
    ''

exports.videoRssForConference = (conf, size, callback) ->
  url = "#{Root}/events/#{conf}"
  YQL.exec "select * from html where url=\"#{url}\" and xpath='//div[@class=\"title\"]/a'", (response) ->
    results = response.query.results.a
    promises = (promiseYQL("select * from html where url=\"#{Root}#{result.href}\" and xpath='//div[@class=\"assets\"]/div/a[contains(text(), \"#{size}\")] | //div[@class=\"video-presenters\"]/a[text()] | //div[@class=\"video-title\"]/p[text()] | //div[@class=\"video-posted-on\"]/p/strong[text()]'") for result in results)
    Promise.all(promises).then (results) ->
      tmpl = "<?xml version='1.0' encoding='UTF-8' ?>
      <rss version='2.0'>
        <channel>
          <title>#{conf} - #{size}</title>
          <link>#{url}</link>
          <description>An RSS feed for #{conf} in #{size}</description>
          #{(makeRss(item.query.results) for item in results).join("\n")}
        </channel>
      </rss>"
      callback(tmpl)