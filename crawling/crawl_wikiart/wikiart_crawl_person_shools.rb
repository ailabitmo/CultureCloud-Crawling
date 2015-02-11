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

schools = []
@graph = RDF::Graph.new(:format => :ttl)

authors_json.each_key { |dbpedia_key|
  puts dbpedia_key
  wikiart_url=authors_json[dbpedia_key]['wikiart_url']
  Nokogiri::HTML(open_html(wikiart_url)).css('body').css('span[itemprop="painting school"]').each { |painting_school|
    @graph << [RDF.URI(dbpedia_key),@rmlod_vocabulary['painting_school'],painting_school.text]
    schools.push(painting_school.text)
  }
}

puts schools.uniq

puts
puts '== Writing file =='
puts
file = File.new('../results/wikiart_persons_schools.ttl', 'w')
file.write(@graph.dump(:ttl, :prefixes => @rdf_prefixes))
file.close