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

module EveryPolitician
  class ScraperRun
    def initialize(id: SecureRandom.uuid, table: 'data', index_fields: nil, default_index_fields: %i(id term))
      @run_data = { id: id, started: Time.now }
      @table = table
      @index_fields = index_fields
      @default_index_fields = default_index_fields
      ScraperWiki.save_sqlite(%i(id), run_data, 'runs')
      ScraperWiki.sqliteexecute('DELETE FROM %s' % table) rescue nil
    end

    def save_all(data, debugging: ENV['MORPH_PRINT_DATA'])
      data.each { |r| puts r.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if debugging
      ScraperWiki.save_sqlite(index_fields_from(data), data, table)
      ScraperWiki.save_sqlite(%i(id), run_data.merge(ended: Time.now), 'runs')
    end

    def error(e)
      ScraperWiki.save_sqlite(%i(id), run_data.merge(errored: Time.now), 'runs')
      # TODO: do something better with the error
      raise e
    end

    private

    attr_reader :run_data, :table, :index_fields, :default_index_fields

    def index_fields_from(data)
      index_fields || (data.first.keys & default_index_fields)
    end
  end

  class Scraper
    def initialize
      @scraper_run = EveryPolitician::ScraperRun.new
    end

    def run
      scraper_run.save_all(data)
    rescue => e
      scraper_run.error(e)
    end

    private

    def scrape(h)
      url, klass = h.to_a.first
      klass.new(response: Scraped::Request.new(url: url).response)
    end

    class IndexToMembers < Scraper
      def initialize(url:, members_class:, member_class:, default_data: {})
        @url = url
        @members_class = members_class
        @member_class = member_class
        @default_data = default_data
        super()
      end

      def data
        scrape(url => members_class).members.map do |mem|
          default_data.merge(mem.to_h).merge(scrape(mem.source => member_class).to_h)
        end
      end

      private

      attr_reader :scraper_run, :url, :members_class, :member_class, :default_data
    end
  end
end

EveryPolitician::Scraper::IndexToMembers.new(
  url:           'http://www.cdep.ro/pls/parlam/structura2015.de?leg=2012&idl=2',
  members_class: MembersPage,
  member_class:  MemberPage,
  default_data:  { term: 2012 }
).run
