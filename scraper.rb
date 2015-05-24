#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'date'
require 'open-uri'
require 'date'
require 'uri'

require 'colorize'
require 'pry'
require 'csv'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

@BASE = 'http://www.cdep.ro'
@COD = '/pls/parlam/structura2015.de?leg=%d&idl=2'

class String
  def trim
    self.gsub(/[[:space:]]/,' ').strip
  end
end

def datefrom(date)
  return if date.nil? or date.empty?
  Date.parse(date)
end

def noko_for(url)
  # warn "Getting #{url}"
  Nokogiri::HTML(open(url).read) 
end

%w(1990 1992 1996 2000 2004 2008 2012).each do |year|
  warn "Getting #{year}"
  added = 0
  term_url = @BASE + @COD % year
  noko = noko_for(term_url)

  (term_start, term_end) = noko.css('.stiri-box h3').last.text.match(/(\d{4})\s*-\s*(\d{4})/).captures
  term = { 
    id: year,
    name: year,
    start_date: term_start,
    end_date: term_end,
  }
  ScraperWiki.save_sqlite([:id], term, 'terms')

  noko.css('div.grup-parlamentar-list table a[href*="idm="]/@href').map(&:text).each do |mp_link|
    mp_url = URI.join(term_url, mp_link)
    box = noko_for(mp_url).css('div.stiri-box')
    dep = box.xpath('.//h3[contains(.,"DEPUTY")]/..')
    national = dep.text.include? 'la nivel national'

    # TODO: find a unique ID, or check the "Alte legislaturi" box for
    # previously seen
    id = year + "-" + mp_url.to_s[/idm=(\d+)/, 1]

    data = { 
      id: id,
      name: box.css('table').first.xpath('.//tr/td/text()').last.text.gsub('>',' ').strip,
      photo: box.css('.profile-pic-dep img/@src').text, # TODO
      # birth_date: box.css('.profile-pic-dep').text.strip.match(/b\.\s+ (.*)/)[1], # TODO — not given if no image!
      area: national ? 'National' : dep.css('a[href*="cir="]').first.text,
      faction: box.css('a[href*="idg="]').first.text,
      faction_id: box.css('a[href*="idg="]/@href').first.text[/idg=(\d+)/, 1],
      party: box.css('a[href*="idp="]').first.text,
      party_id: box.css('a[href*="idp="]/@href').first.text[/idp=(\d+)/, 1],
      start_date: datefrom(dep.text[/start of the mandate: (\d+\s+\w+\s+\d+)/, 1]).to_s,
      end_date: datefrom(dep.text[/end of the mandate: (\d+\s+\w+\s+\d+)/, 1]).to_s,
      source: mp_url.to_s,
      term: year,
    }
    data[:photo].prepend @BASE unless data[:photo].nil? or data[:photo].empty?
    added += 1
    ScraperWiki.save_sqlite([:id, :term], data)
  end
  puts "Added #{added} for #{year}"
end

