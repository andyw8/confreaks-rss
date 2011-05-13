#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

require 'em-synchrony/em-http'

class Confreaks < Goliath::API
  Root = 'http://confreaks.net'
  Headers = {
    'User-Agent' => "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_6; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10"
  }

  # use ::Rack::Reloader, 0 if Goliath.dev?

  def cache
    @cache ||= Dalli::Client.new
  end

  def week_of_year
    (Date.today.strftime('%j').to_f / 7).ceil
  end

  def key_for_url(url)
    [url.hash.to_s, Date.today.year, week_of_year].join(':')
  end

  def blocking_fetch_url(url)
    key = key_for_url(url)
    cached = cache.get(key)
    return cached if cached
    req = EM::HttpRequest.new(url).get
    return nil unless 200 == req.response_header.status
    resp = req.response
    cache.set(key, resp)
    resp
  end

  def response(env)
    case env['PATH_INFO']
    when %r{/(?<conf>[^/]+)/(?<size>.*)}
      conf, size = $1, $2

      conf_url = "#{Root}/events/#{conf}"
      body = blocking_fetch_url(conf_url)
      return [500, {}, 'Error retrieving main conference page'] if body.nil?

      presentation_urls = Nokogiri::HTML(body).search('.title a').map { |a| Root + a[:href] }

      pages = EM::Synchrony::Iterator.new(presentation_urls, 5).map do |url, iter|
        key = key_for_url(url)
        cache.aget(key) do |cached|
          if cached.nil?
            http = EM::HttpRequest.new(url).aget
            http.callback do
              if 200 == http.response_header.status
                cache.aset(key, http.response) { p :stored }
                iter.return(http.response)
              else
                iter.return(nil)
              end
            end
          else
            iter.return(cached)
          end
        end
      end.compact

      docs = pages.map { |page| Nokogiri::HTML(page) }

      builder = Builder::XmlMarkup.new
      builder.instruct!
      rss = builder.rss(:version => '2.0') do |xml|
        xml.channel do
          xml.title("#{conf} - #{size}")
          xml.link(conf_url)
          xml.description("An RSS feed for #{conf} with size matching #{size}")
          docs.each do |video_doc|
            title = video_doc.search('.video-title').text.strip
            author = video_doc.search('.video-presenters').text.strip
            video_href = video_doc.search('.assets a').select { |a| a.text.include?(size) }.first
            next if video_href.nil?
            video = Root + video_href[:href]
            xml.item do
              xml.title("#{title} - #{author}")
              xml.author(author)
              xml.guid(video)
              xml.pubDate(video_doc.search('.video-posted-on strong').text.strip)
              xml.enclosure(:url => video, :length => video_href.text.split(' - ').last, :type => video_href.text.split(' - ')[1])
            end
          end
        end
      end
      return [200, { 'Content-Type' => 'application/rss+xml' }, rss]
    end
    [404, {}, 'Not Found']
  end
end