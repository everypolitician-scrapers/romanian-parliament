#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

class String
  def to_date
    return if empty?
    Date.parse(self).to_s rescue ''
  end
end

class MembersPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :members do
    noko.css('.grup-parlamentar-list').xpath('.//table//tr[td]').map do |tr|
      fragment tr => MemberRow
    end
  end
end

class MemberRow < Scraped::HTML
  field :id do
    source[/idm=(\d+)/, 1]
  end

  field :sort_name do
    tds[1].text.tidy
  end

  field :faction do
    tds[4].text.tidy
  end

  field :area do
    area_data.last
  end

  field :area_id do
    area_data.first
  end

  field :source do
    tds[1].css('a/@href').text
  end

  field :start_date do
    tds[5].text.to_s.to_date
  end

  field :end_date do
    tds[6].text.to_s.to_date if tds[6]
  end

  private

  def area_data
    tds[2].text.split(%r{\s*/\s*}, 2).map(&:tidy)
  end

  def tds
    @tds ||= begin
      tds = noko.css('td').to_a
      tds.insert(3, nil) if tds.count == 5 # combined constituency
      tds
    end
  end
end

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :name do
    box.xpath('.//h1/text()').first.text.tidy rescue binding.pry
  end

  field :image do
    box.css('.profile-pic-dep img/@src').text
  end

  field :birth_date do
    box.css('.profile-pic-dep').text.tidy.to_s.to_date
  end

  field :email do
    box.css('span.mailInfo').map(&:text).join(';')
  end

  private

  def box
    noko.css('.stiri-detalii')
  end
end

module Everypolitician
  class Scraper
    def initialize(config: {}, default_data: {}, unique_fields: nil, default_unique_fields: %i(id term start_date))
      @config = config
      @default_data = default_data
      @unique_fields = unique_fields
      @default_unique_fields = default_unique_fields
    end

    def to_a
      data_with_defaults
    end

    def index_fields
      unique_fields || (data.first.keys & default_unique_fields)
    end

    private

    attr_reader :config, :default_data, :unique_fields, :default_unique_fields

    def data_with_defaults
      @data_with_defaults ||= data.map { |d| default_data.merge(d) }
    end

    def scrape(h)
      url, klass = h.to_a.first
      klass.new(response: Scraped::Request.new(url: url).response)
    end
  end
end

class RomanianParliamentScraper < Everypolitician::Scraper
  def data
    scrape(config[:url] => MembersPage).members.map do |mem|
      mem.to_h.merge(scrape(mem.source => MemberPage).to_h)
    end
  end
end

scraper = RomanianParliamentScraper.new(
  config: {
    url: 'http://www.cdep.ro/pls/parlam/structura2015.de?leg=2012&idl=2'
  },
  default_data: { term: 2012 },
  unique_fields: %i(id term)
)

# puts scraper.to_a.map { |r| r.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h }

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite(scraper.index_fields, scraper.to_a)
