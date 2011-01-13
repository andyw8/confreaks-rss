Url = require('url')
Sys = require('sys')
Query = require('querystring')
Http = require('http')
YQL = require('yql')
Continuables = require('./continuables')

Root = 'http://confreaks.net'

Promise = (func, args...) ->
  continuable = Continuables.create()
  args.push (response) ->
    continuable.fulfill(response)
  func.apply this, args
  continuable

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
    item.a[0].content
  catch boom
    'Unknown'

makeRss = (item) ->
  [author, url, length] = [getAuthor(item), getUrl(item), getLength(item)]
  if url?
    "
    <item>
      <title>#{item.p} - #{author}</title>
      <author>#{author}</author>
      <guid>#{url}</guid>
      <pubDate>#{item.strong}</pubDate>
      <enclosure url='#{url}' length='#{length}' type='video/mp4' />
    </item>
    "
  else
    ''

Http.createServer((req, res) ->
  try
    url = Url.parse(req.url)
    query = Query.parse(url.query)
    if query.conf? && query.size?
      title = query.conf.split('/').pop()
      YQL.exec "select * from html where url=\"#{query.conf}\" and xpath='//div[@class=\"title\"]/a'", (response) ->
        results = response.query.results.a

        results.forEach (result) ->
          result['promise'] = Promise(YQL.exec, "select * from html where url=\"#{Root}#{result.href}\" and xpath='//div[@class=\"assets\"]/div/a[contains(text(), \"#{query.size}\")] | //div[@class=\"video-presenters\"]/a[text()] | //div[@class=\"video-title\"]/p[text()] | //div[@class=\"video-posted-on\"]/p/strong[text()]'")

        Continuables.group((result.promise for result in results))((result) ->
          tmpl = "<?xml version='1.0' encoding='UTF-8' ?>
          <rss version='2.0'>
            <channel>
              <title>#{title} - #{query.size}</title>
              <link>#{query.conf}</link>
              <description>An RSS feed for #{query.conf} in #{query.size}</description>
              #{(makeRss(item.query.results) for item in result).join("\n")}
            </channel>
          </rss>"

          res.writeHead(200, {
            'Content-Type': 'text/xml'
          })
          res.end(tmpl)
        )
    else
      res.writeHead(400, {
        'Content-Type': 'text/plain'
      })
      res.end('Fail')
  catch boom
    res.writeHead(500, {
      'Content-Type': 'text/plain'
    })
    res.end(boom.message)
).listen(9090)