# frozen_string_literal: true

require 'minitest/around/spec'
require 'minitest/autorun'
require 'pry'
require 'vcr'
require 'webmock'

VCR.configure do |c|
  c.cassette_library_dir = 'test/cassettes'
  c.hook_into :webmock
end
