require 'set'
require 'net/http'
require 'nokogiri'
require 'rdf/turtle'
include RDF
require 'rdf/xsd'

def open_html(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 1
  http.read_timeout = 10
  begin
    response = http.get(uri.path)
  rescue Net::OpenTimeout
    puts 'Caught new Net::OpenTimeout exception. Press return to retry (recommended) or Ctrl+C to interrupt (the data will be lost in that case).'
    retry
  end
  response.body
end

@artwork_ids = (Proc.new {
  artworks_ids = Set.new
  RDF::Query::Pattern.new(:s, RDF::URI.new('http://erlangen-crm.org/current/P14_carried_out_by'), :o).
      execute(RDF::Graph.load('../results/rmgallery_artwork_ownerships.ttl')).each do |statement|
    artworks_ids << /\d+/.match(statement.subject)[0]
  end
  artworks_ids
}).call
puts 'IDs loaded'

@ecrm = RDF::Vocabulary('http://erlangen-crm.org/current/')
@graph = RDF::Graph.new(:format => :ttl)
@bmthes_width = RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/dimension/width')
@bmthes_height = RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/dimension/height')

def add_dimensions(object_id, width, height)
  object_uri_str = "http://rm-lod.org/object/#{object_id}"
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
  Nokogiri::HTML(open_html("http://rmgallery.ru/ru/#{object_id}")).css('b').each do |descr|
    s = descr.to_s.gsub(' ','').gsub(',','.').gsub('×','x').gsub('х', 'x')
    m = /(\d+\.?\d*)x(\d+\.?\d*).*/.match(s)
    if m.nil?
      puts "No dimensions for #{object_id}?"
      next
    end
    add_dimensions(object_id, m[1], m[2])
  end
end

@artwork_ids.each do |id|
  crawl_dimensions(id)
end

@rdf_prefixes = {
    :xsd  => XSD.to_uri,
    :rdf  => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :owl  => OWL.to_uri,
    :ecrm => RDF::URI.new('http://erlangen-crm.org/current/'),
    'rm-lod' => RDF::URI.new('http://rm-lod.org/')
}

puts 'Writing file'
File.open('../results/rmgallery_artwork_dimensions.ttl', 'w') do |f|
  f.write(@graph.dump(:ttl, :prefixes => @rdf_prefixes))
end
