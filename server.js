(function() {
  var Continuables, Http, Promise, Query, Root, Sys, Url, YQL, getAuthor, getLength, getUrl, makeRss;
  var __slice = Array.prototype.slice;
  Url = require('url');
  Sys = require('sys');
  Query = require('querystring');
  Http = require('http');
  YQL = require('yql');
  Continuables = require('./continuables');
  Root = 'http://confreaks.net';
  Promise = function() {
    var args, continuable, func;
    func = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    continuable = Continuables.create();
    args.push(function(response) {
      return continuable.fulfill(response);
    });
    func.apply(this, args);
    return continuable;
  };
  getUrl = function(item) {
    try {
      return "" + Root + (item.a[1].href.split('?')[0]);
    } catch (boom) {
      return null;
    }
  };
  getLength = function(item) {
    try {
      return item.a[1].content.split(' - ')[3];
    } catch (boom) {
      return '00:00';
    }
  };
  getAuthor = function(item) {
    try {
      return item.a[0].content;
    } catch (boom) {
      return 'Unknown';
    }
  };
  makeRss = function(item) {
    var author, length, url, _ref;
    _ref = [getAuthor(item), getUrl(item), getLength(item)], author = _ref[0], url = _ref[1], length = _ref[2];
    if (url != null) {
      return "    <item>      <title>" + item.p + " - " + author + "</title>      <author>" + author + "</author>      <guid>" + url + "</guid>      <pubDate>" + item.strong + "</pubDate>      <enclosure url='" + url + "' length='" + length + "' type='video/mp4' />    </item>    ";
    } else {
      return '';
    }
  };
  Http.createServer(function(req, res) {
    var query, title, url;
    try {
      url = Url.parse(req.url);
      query = Query.parse(url.query);
      if ((query.conf != null) && (query.size != null)) {
        title = query.conf.split('/').pop();
        return YQL.exec("select * from html where url=\"" + query.conf + "\" and xpath='//div[@class=\"title\"]/a'", function(response) {
          var result, results;
          results = response.query.results.a;
          results.forEach(function(result) {
            return result['promise'] = Promise(YQL.exec, "select * from html where url=\"" + Root + result.href + "\" and xpath='//div[@class=\"assets\"]/div/a[contains(text(), \"" + query.size + "\")] | //div[@class=\"video-presenters\"]/a[text()] | //div[@class=\"video-title\"]/p[text()] | //div[@class=\"video-posted-on\"]/p/strong[text()]'");
          });
          return Continuables.group((function() {
            var _i, _len, _results;
            _results = [];
            for (_i = 0, _len = results.length; _i < _len; _i++) {
              result = results[_i];
              _results.push(result.promise);
            }
            return _results;
          })())(function(result) {
            var item, tmpl;
            tmpl = "<?xml version='1.0' encoding='UTF-8' ?>          <rss version='2.0'>            <channel>              <title>" + title + " - " + query.size + "</title>              <link>" + query.conf + "</link>              <description>An RSS feed for " + query.conf + " in " + query.size + "</description>              " + (((function() {
              var _i, _len, _results;
              _results = [];
              for (_i = 0, _len = result.length; _i < _len; _i++) {
                item = result[_i];
                _results.push(makeRss(item.query.results));
              }
              return _results;
            })()).join("\n")) + "            </channel>          </rss>";
            res.writeHead(200, {
              'Content-Type': 'text/xml'
            });
            return res.end(tmpl);
          });
        });
      } else {
        res.writeHead(400, {
          'Content-Type': 'text/plain'
        });
        return res.end('Fail');
      }
    } catch (boom) {
      res.writeHead(500, {
        'Content-Type': 'text/plain'
      });
      return res.end(boom.message);
    }
  }).listen(9090);
}).call(this);
