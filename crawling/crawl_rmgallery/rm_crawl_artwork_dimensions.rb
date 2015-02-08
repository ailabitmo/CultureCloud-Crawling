require 'set'
require 'net/http'
require 'nokogiri'
require 'rdf/turtle'
include RDF
require 'rdf/xsd'
require './rm_crawl_common'

@ecrm = RDF::Vocabulary.new('http://erlangen-crm.org/current/')
@graph = RDF::Graph.new(:format => :ttl)
@bmthes_width = RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/dimension/width')
@bmthes_height = RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/dimension/height')

def add_dimensions(object_id, width, height)
  object_uri_str = "http://culturecloud.ru/resource/object/#{object_id}"
  object_uri = RDF::URI.new(object_uri_str)
  width_uri = RDF::URI.new("#{object_uri_str}/width/#{width}")
  height_uri = RDF::URI.new("#{object_uri_str}/height/#{height}")

  @graph << [object_uri, @ecrm['P43_has_dimension'], width_uri]
  @graph << [width_uri, RDF.type, @ecrm['E54_Dimension']]
  @graph << [width_uri, RDF.type, OWL.NamedIndividual]
  @graph << [width_uri, @ecrm['P2_has_type'], @bmthes_width]
  @graph << [width_uri, @ecrm['P90_has_value'], RDF::Literal::Float.new(width)]

  @graph << [object_uri, @ecrm['P43_has_dimension'], height_uri]
  @graph << [height_uri, RDF.type, @ecrm['E54_Dimension']]
  @graph << [height_uri, RDF.type, OWL.NamedIndividual]
  @graph << [height_uri, @ecrm['P2_has_type'], @bmthes_height]
  @graph << [height_uri, @ecrm['P90_has_value'], RDF::Literal::Float.new(height)]
end

def crawl_dimensions(object_id)
  Nokogiri::HTML(get_cached_artwork_page(object_id, :ru)).css('b').each do |descr|
    s = descr.to_s.gsub(' ','').gsub(',','.').gsub('×','x').gsub('х', 'x')
    m = /(\d+\.?\d*)x(\d+\.?\d*).*/.match(s)
    if m.nil?
      puts "No dimensions for #{object_id}?"
      next
    end
    add_dimensions(object_id, m[1], m[2])
  end
end

get_artwork_ids.each do |id|
  crawl_dimensions(id)
end

puts 'Writing file'
File.open('rm_artwork_dimensions.ttl', 'w') do |f|
  f.write(@graph.dump(:ttl, :prefixes => @rdf_prefixes))
end
