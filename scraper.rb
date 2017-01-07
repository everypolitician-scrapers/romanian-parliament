#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'scraperwiki'
require 'nokogiri'
require 'pry'

require 'scraped_page_archive/open-uri'
# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def date_parse(str)
  return if str.to_s.empty?
  return Date.parse(str).to_s rescue ''
end

def scrape_list(url)
  noko = noko_for(url)

  noko.css('.grup-parlamentar-list table').each_with_index do |table, _i|
    table.xpath('.//tr[td]').each do |tr|
      tds = tr.css('td').to_a
      tds.insert(3, nil) if tds.count == 5 # combined constituency

      link = URI.join url, tds[1].css('a/@href').text
      area_id, area = tds[2].text.split(/\s*\/\s*/, 2).map(&:tidy)
      data = {
        id:      link.to_s[/idm=(\d+)/, 1],
        name:    tds[1].text.tidy,
        faction: tds[4].text.tidy,
        area:    area,
        area_id: area_id,
        term:    2012,
        source:  link.to_s,
      }.merge(scrape_person(link))
      data[:start_date] = date_parse(tds[5].text)
      data[:end_date]   = date_parse(tds[6].text) if tds.count == 7

      ScraperWiki.save_sqlite(%i(id term), data)
    end
  end
end

def scrape_person(url)
  noko = noko_for(url)
  box = noko.css('.stiri-detalii')
  data = {
    sort_name:  box.xpath('.//h1/text()').first.text.tidy,
    image:      box.css('.profile-pic-dep img/@src').text,
    birth_date: date_parse(box.css('.profile-pic-dep').text.tidy),
    email:      box.css('span.mailInfo').map(&:text).join(';'),
    # TODO: history of parliamentary groups
  }
  data[:image] = URI.join(url, URI.escape(data[:image])).to_s unless data[:image].to_s.empty?
  data
end

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
scrape_list('http://www.cdep.ro/pls/parlam/structura2015.de?leg=2012&idl=2')
