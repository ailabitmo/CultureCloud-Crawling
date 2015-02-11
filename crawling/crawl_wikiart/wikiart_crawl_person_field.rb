# encoding: utf-8
require '../rm_crawl_common.rb'
require '../rm_enrich_common.rb'
require 'nokogiri'
require 'rdf/turtle'
require 'net/http'
require 'unicode'
require 'securerandom'
require 'digest/md5'
require 'json'
include RDF

file = File.read('our_authors.json')
authors_json = JSON.parse(file)

@graph = RDF::Graph.new(:format => :ttl)

fields = []

authors_json.each_key { |dbpedia_key|
  puts dbpedia_key
  wikiart_url=authors_json[dbpedia_key]['wikiart_url']
  Nokogiri::HTML(open_html(wikiart_url)).css('body').css('p[class="pt10 b0"]').each { |row_item|
    row_item_text=row_item.text.strip
    if row_item_text.start_with?("Field:")
    then
      row_item_text.split("\n").last.strip.split(',').each { |field|
        field_text=field.strip
        @graph << [RDF.URI(dbpedia_key),@rmlod_vocabulary['artist_field'],RDF::Literal.new(field_text, :language => :en)]
        fields.push(field_text)
      }
    end
  }
}
puts fields.uniq

puts
puts '== Writing file =='
puts
file = File.new('../results/wikiart_persons_fields.ttl', 'w')
file.write(@graph.dump(:ttl, :prefixes => @rdf_prefixes))
file.close