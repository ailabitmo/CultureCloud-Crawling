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

nations = []
@graph = RDF::Graph.new(:format => :ttl)

authors_json.each_key { |dbpedia_key|
  puts dbpedia_key
  wikiart_url=authors_json[dbpedia_key]['wikiart_url']
  Nokogiri::HTML(open_html(wikiart_url)).css('body').css('span[itemprop="nation"]').each { |nationality|
    nationality_text=nationality.text
    @graph << [RDF.URI(dbpedia_key),@dbpedia_vocabulary['nationality'],RDF::Literal.new(nationality_text, :language => :en)]
    nations.push(nationality_text)
  }
}

puts nations.uniq

puts
puts '== Writing file =='
puts
file = File.new('../results/wikiart_persons_nationalities.ttl', 'w')
file.write(@graph.dump(:ttl, :prefixes => @rdf_prefixes))
file.close