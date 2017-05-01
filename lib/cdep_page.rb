# frozen_string_literal: true

require 'scraped'

class String
  def to_date
    return if empty?
    Date.parse(self).to_s rescue ''
  end
end

class CdepPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls
end
