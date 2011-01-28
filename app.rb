#!/usr/bin/env ruby

require 'bundler/setup'
require 'sinatra'
require 'excon'
require 'nokogiri'
require 'active_support/cache'
require 'active_support/cache/dalli_store'

Root = 'http://confreaks.net'
Cache = ActiveSupport::Cache::DalliStore.new
Headers = {
  'User-Agent' => "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_6; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10"
}

helpers do
  def expires_in
    (rand * 7 + 7).days
  end

  def fetch_url(url)
    Cache.fetch(url.hash.to_s, :expires_in => expires_in) do
      resp = Excon.get(url, :headers => Headers)
      raise "Invalid URL" unless resp.status == 200
      resp.body
    end
  end
end

get '/:conf/:size' do |conf, size|
  content_type 'application/rss+xml'
  key = [conf, size, Date.today.to_s, 'rss'].join(':')
  Cache.fetch(key) do
    url = "#{Root}/events/#{conf}"
    body = fetch_url(url)
    doc = Nokogiri::HTML(body)
    links = doc.search('.title a').map { |a| Root + a[:href] }
    bodies = links.map { |link| fetch_url(url) }
    builder do |xml|
      xml.instruct!
      xml.rss(:version => '2.0') do
        xml.channel do
          xml.title("#{conf} - #{size}")
          xml.link(url)
          xml.description("An RSS feed for #{conf} with size matching #{size}")
          bodies.each do |body|
            video_doc = Nokogiri::HTML(body)
            title = video_doc.search('.video-title').text.strip
            author = video_doc.search('.video-presenters').text.strip
            video_href = video_doc.search('.assets a').select { |a| a.text.include?(size) }.first
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
    end
  end
end