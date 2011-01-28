#!/usr/bin/env ruby

require 'bundler/setup'
require 'sinatra'
require 'excon'
require 'nokogiri'
require 'active_support/cache/dalli_store'

Root = 'http://confreaks.net'
# Cache = ActiveSupport::Cache::DalliStore

get '/:conf/:size' do |conf, size|
  'hello'
end