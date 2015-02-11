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

authors_json.each_key { |dbpedia_key|
  puts dbpedia_key
  wikiart_url=authors_json[dbpedia_key]['wikiart_url']
  Nokogiri::HTML(open_html(wikiart_url)).css('body').css('div[id="Biography"]').each { |biography|
    biography_text=biography.text.strip
    if biography_text!=""
    then
      @graph << [RDF.URI(dbpedia_key), @ecrm_vocabulary['P3_has_note'], RDF::Literal.new(biography_text, :language => :en)]
    end
  }
}

puts
puts '== Writing file =='
puts
file = File.new('../results/wikiart_persons_biographies.ttl', 'w')
file.write(@graph.dump(:ttl, :prefixes => @rdf_prefixes))
file.close