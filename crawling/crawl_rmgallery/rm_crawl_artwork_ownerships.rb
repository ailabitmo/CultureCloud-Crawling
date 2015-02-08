require 'nokogiri'
require 'rdf/turtle'
require 'net/http'
require 'unicode'
require 'set'
require './rm_crawl_common'
include RDF

@p14_carried_out_by = RDF::URI.new('http://erlangen-crm.org/current/P14_carried_out_by')

def gen_statement(person_id, object_id)
  person_uri = RDF::URI.new("http://culturecloud.ru/resource/person/#{person_id}")
  production_uri = RDF::URI.new("http://culturecloud.ru/resource/object/#{object_id}/production")
  RDF::Statement(production_uri, @p14_carried_out_by, person_uri)
end

@graph = RDF::Graph.new(:format => :ttl)

# Crawl targets
@base_url = 'http://rmgallery.ru'
@css_path = 'div[data-role=controlgroup]'

puts
puts '== Getting paintings and drawing IDs =='
puts
@object_ids = Set.new
%w(216 217).each do |page|
  Nokogiri::HTML(open_html('http://rmgallery.ru/ru/' + page))
      .css(@css_path).css('a').each do |link|
    @object_ids << link['href'][4, link['href'].length]
  end
end
puts @object_ids.size.to_s + ' IDs in total'

puts
puts '== Downloading object pages =='
puts
@object_ids.each do |id|
  page_ru = open_html('http://rmgallery.ru/ru/' + id)
  page_en = open_html('http://rmgallery.ru/en/' + id)
  IO.write("./rmgallery_site/objects/ru/#{id}.html", page_ru)
  IO.write("./rmgallery_site/objects/en/#{id}.html", page_en) unless page_en.nil?
end

puts
puts '== Crawling =='
puts
Nokogiri::HTML(open_html(@base_url + '/ru/author')).css(@css_path).css('a').each do |person|
  person_id = person['href'][4, person['href'].length].strip
  person_name = person.text.strip
  Nokogiri::HTML(open_html(@base_url + person['href'])).css(@css_path).css('a').each do |artwork|
    object_id = artwork['href'][4, artwork['href'].length].strip
    next unless @object_ids.include?(object_id)
    puts person_name + ' ' + object_id + ' ' + artwork['href']
    @graph << gen_statement(person_id, object_id)
  end
end

puts
puts '== Writing file =='
puts
file = File.new('rm_artwork_ownerships.ttl', 'w')
file.write(@graph.dump(:ttl, :prefixes => @rdf_prefixes))
file.close
puts 'Done!'

