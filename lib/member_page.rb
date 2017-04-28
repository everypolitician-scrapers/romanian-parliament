# frozen_string_literal: true

require 'scraped'
require 'pry'

class String
  def to_date
    return if empty?
    Date.parse(self).to_s rescue ''
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
