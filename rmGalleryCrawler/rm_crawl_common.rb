require 'set'
require 'net/http'
require 'nokogiri'
require 'rdf/turtle'
require 'rdf/xsd'
include RDF

@user_agent = 'Mozilla/5.0 (Windows NT 6.3; rv:36.0) Gecko/20100101 Firefox/36.0'
def open_html(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  begin
    response = http.get(uri.path, 'User-Agent' => @user_agent)
  rescue Net::OpenTimeout
    puts 'open_html: Net::OpenTimeout exception. Retrying...'
    retry
  end
  response.body
end

def get_artwork_ids()
  artworks_ids = Set.new
  RDF::Query::Pattern.new(:s, RDF::URI.new('http://erlangen-crm.org/current/P14_carried_out_by'), :o).
      execute(RDF::Graph.load('rm_artwork_ownerships.ttl')).each do |statement|
    artworks_ids << /\d+/.match(statement.subject)[0]
  end
  puts 'IDs loaded'
  artworks_ids
end

@ecrm = RDF::Vocabulary.new('http://erlangen-crm.org/current/')
@rdf_prefixes = {
    :xsd  => XSD.to_uri,
    :rdf  => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :owl  => OWL.to_uri,
    :skos  => SKOS.to_uri,
    :ecrm => RDF::URI.new('http://erlangen-crm.org/current/'),
    'rm-lod' => RDF::URI.new('http://rm-lod.org/')
}