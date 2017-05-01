# frozen_string_literal: true

require 'scraped'

class MembersPage < CdepPage
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

  field :term do
    2012
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
