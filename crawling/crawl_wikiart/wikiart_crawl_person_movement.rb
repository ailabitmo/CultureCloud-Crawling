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

@dbpedia_resource_prefix="http://dbpedia.org/resoure"
@movements_hash = {
    'Romanticism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Romanticism"),
    'Neoclassicism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Neoclassicism"),
    'Cubism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Cubism"),
    'Futurism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Futurism"),
    'Baroque' => RDF::URI.new("#{@dbpedia_resource_prefix}/Baroque"),
    'Art Nouveau' => RDF::URI.new("#{@dbpedia_resource_prefix}/Art_Nouveau"),
    'Symbolism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Symbolism_(arts)"),
    'Realism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Realism_(arts)"),
    'Cubo-Futurism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Cubo-Futurism"),
    'Rococo' => RDF::URI.new("#{@dbpedia_resource_prefix}/Rococo"),
    'Expressionism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Expressionism"),
    'Suprematism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Suprematism"),
    'Constructivism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Constructivism_(art)"),
    'Art Deco' => RDF::URI.new("#{@dbpedia_resource_prefix}/Art_Deco"),
    'Rayonism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Rayonism"),
    'Academic Art' => RDF::URI.new("#{@dbpedia_resource_prefix}/Academic_Art"),
    'Abstract Art' => RDF::URI.new("#{@dbpedia_resource_prefix}/Abstract_Art"),
    'Post-Impressionism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Post-Impressionism"),
    'Socialist Realism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Socialist_realism"),
    'Impressionism' => RDF::URI.new("#{@dbpedia_resource_prefix}/Impressionism"),
}

@graph = RDF::Graph.new(:format => :ttl)

authors_json.each_key { |dbpedia_key|
  puts dbpedia_key
  wikiart_url=authors_json[dbpedia_key]['wikiart_url']
  Nokogiri::HTML(open_html(wikiart_url)).css('body').css('span[itemprop="art movement"]').each { |art_movement|
    art_movement_text=art_movement.text
    @graph << [RDF.URI(dbpedia_key),@dbpedia_vocabulary['movement'],@movements_hash[art_movement_text]]
  }
}

puts
puts '== Writing file =='
puts
file = File.new('../results/wikiart_persons_dbp_movements.ttl', 'w')
file.write(@graph.dump(:ttl, :prefixes => @rdf_prefixes))
file.close