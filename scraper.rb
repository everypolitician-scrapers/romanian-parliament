#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
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

  noko.css('.grup-parlamentar-list table').each_with_index do |table, i|
    table.xpath('.//tr[td]').each do |tr|
      tds = tr.css('td').to_a
      tds.insert(3, nil) if tds.count == 5 # combined constituency

      link = URI.join url, tds[1].css('a/@href').text
      date_field = i == 0 ? 'start_date' : 'end_date'
      area_id, area = tds[2].text.split(/\s*\/\s*/, 2).map(&:tidy)

      data = { 
        id: link.to_s[/idm=(\d+)/, 1],
        name: tds[1].text.tidy,
        faction: tds[4].text.tidy,
        area: area,
        area_id: area_id,
        term: 2012,
        source: link.to_s,
      }.merge(scrape_person(link))
      data[date_field] = date_parse(tds[5].text)
      puts data[:name]
      ScraperWiki.save_sqlite([:id, :term], data)
    end
  end
end

def scrape_person(url)
  noko = noko_for(url)
  box = noko.css('.stiri-detalii')
  data = { 
    sort_name: box.css('h1').text.tidy,
    image: box.css('.profile-pic-dep img/@src').text,
    birth_date: date_parse(box.css('.profile-pic-dep').text.tidy),
    email: box.css('span.mailInfo').text,
    #TODO history of parliamentary groups
  }
  data[:image] = URI.join(url, URI.escape(data[:image])).to_s unless data[:image].to_s.empty?
  data
end

scrape_list('http://www.cdep.ro/pls/parlam/structura2015.de?leg=2012&idl=2')
