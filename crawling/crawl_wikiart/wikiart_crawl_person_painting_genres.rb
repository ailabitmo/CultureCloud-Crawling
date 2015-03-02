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

genres = []
@graph = RDF::Graph.new(:format => :ttl)

@genres_hash = {
    'abstract painting' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/abstraction'),
    'mythological painting' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x13025'),
    'marina' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x13032'),
    'battle painting' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12993'),
    'religious painting' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x13317'),
    'genre painting' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12718'),
    'illustration' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/illustration'),
    'design' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/design'),
    'history painting' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12859'),
    'landscape' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12934'),
    'portrait' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/portrait'),
    'veduta' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/veduta'),
    'cityscape' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/cityscape')
}

authors_json.each_key { |dbpedia_key|
  puts dbpedia_key
  wikiart_url=authors_json[dbpedia_key]['wikiart_url']
  Nokogiri::HTML(open_html(wikiart_url)).css('body').css('span[itemprop="genre"]').each { |painting_genre|
    painting_genre_text=painting_genre.text

    @graph << [RDF.URI(dbpedia_key),@ecrm_vocabulary[:P2_has_type],@genres_hash[painting_genre_text]]
    genres.push(painting_genre.text)
  }
}

puts genres.uniq

puts
puts '== Writing file =='
puts
file = File.new('../results/wikiart_persons_genres.ttl', 'w')
file.write(@graph.dump(:ttl, :prefixes => @rdf_prefixes))
file.close