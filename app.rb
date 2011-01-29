#!/usr/bin/env ruby

require 'bundler/setup'
require 'sinatra'
require 'excon'
require 'nokogiri'
require 'active_support/cache'
require 'active_support/cache/dalli_store'
require 'builder'

if defined?(PhusionPassenger)
  p 'passenger!'
end

Root = 'http://confreaks.net'
Cache = ActiveSupport::Cache::DalliStore.new
Headers = {
  'User-Agent' => "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_6; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10"
}

helpers do
  def expires_in
    (rand * 7).days
  end

  def fetch_url(url, ttl = expires_in)
    Cache.fetch(url.hash.to_s, :expires_in => ttl) do
      resp = Excon.get(url, :headers => Headers)
      raise "Invalid URL" unless resp.status == 200
      resp.body
    end
  end
end

get '/:conf/:size' do |conf, size|
  content_type 'application/rss+xml'
  url = "#{Root}/events/#{conf}"
  body = fetch_url(url, 1.day)
  docs = Nokogiri::HTML(body).search('.title a').map do |a|
    Root + a[:href]
  end.map { |link| Nokogiri::HTML(fetch_url(link)) }
  builder do |xml|
    xml.instruct!
    xml.rss(:version => '2.0') do
      xml.channel do
        xml.title("#{conf} - #{size}")
        xml.link(url)
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
  end
end