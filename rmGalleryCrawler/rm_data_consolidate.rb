require 'nokogiri'
require 'rdf/turtle'
require 'net/http'
require 'unicode'
require 'securerandom'
require 'digest/md5'
require 'russian'
include RDF

@rdf_prefixes = {
    :ecrm =>  "http://erlangen-crm.org/current/",
    :rdf => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :dbp =>  "http://dbpedia.org/resource/",
    :owl => OWL.to_uri,
    'rm-lod' => "http://rm-lod.org/"
}

@graph = RDF::Graph.new

puts 'Loading'
puts 'dates'
@graph.load('rm_artwork_dates.ttl')
puts 'images'
@graph.load('rm_artwork_images.ttl')
# puts 'materials'
# @graph.load('rm_artwork_materials.ttl')
puts 'objects'
@graph.load('rm_artwork_objects.ttl')
puts 'ownerships'
@graph.load('rm_artwork_ownerships.ttl')
puts 'representation'
@graph.load('rm_artwork_representation.ttl')
puts 'titles'
@graph.load('rm_artwork_titles.ttl')
puts 'concepts'
@graph.load('rm_concepts.ttl')
puts 'genres'
@graph.load('rm_genres.ttl')
puts 'persons'
@graph.load('rm_persons.ttl')


puts '== Writing file =='
file = File.new('rm_data.ttl', 'w')
file.write(@graph.dump(:ttl, :prefixes => @rdf_prefixes))
file.close
puts 'Done!'
