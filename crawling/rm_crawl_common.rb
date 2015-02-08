# encoding: utf-8

require 'rubygems'
require 'io/console'
require 'set'
require 'uri'
require 'net/http'
require 'nokogiri'
require 'rdf/turtle'
require 'rdf/xsd'
include RDF
require 'securerandom'

def get_random_string
  SecureRandom.urlsafe_base64(5)
end

@user_agent = 'Mozilla/5.0 (Windows NT 6.3; rv:36.0) Gecko/20100101 Firefox/36.0'
def open_html(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  # http.open_timeout = 1
  # http.read_timeout = 10
  begin
    response = http.get(uri.path, 'User-Agent' => @user_agent)
  rescue Net::OpenTimeout
    puts 'open_html: Net::OpenTimeout exception. Retrying...'
    retry
  end
  response.body
end

def url_available?(url_str)
  url = URI.parse(url_str)
  Net::HTTP.start(url.host, url.port) do |http|
    return http.head(url.request_uri).code == "200"
  end
end

# Get final Url After Redirects
def get_final_url(url)
    Net::HTTP.get_response(URI(url))['location']
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

@dbpedia_host = "http://dbpedia.org"
@dbpedia_resource_prefix = "#{@dbpedia_host}/resource"
@dbpedia_ontology_prefix = "#{@dbpedia_host}/ontology/"


@rdf_prefixes = {
    :xsd  => XSD.to_uri,
    :rdf  => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :owl  => OWL.to_uri,
    :skos  => SKOS.to_uri,
    :dc  => DC.to_uri,
    #:dbp =>  "http://dbpedia.org/resource/",
    #'dbp-ru' => "http://ru.dbpedia.org/resource/",
    'ecrm' => RDF::URI.new('http://erlangen-crm.org/current/'),
    'rm-lod' => RDF::URI.new('http://rm-lod.org/'),
    'rm-lod-schema' => "http://rm-lod.org/schema/",
    'dbpedia' => @dbpedia_ontology_prefix
}

@ecrm = RDF::Vocabulary('http://erlangen-crm.org/current/') # remove it?
@ecrm_vocabulary = RDF::Vocabulary(@rdf_prefixes['ecrm'])
@rmlod_vocabulary = RDF::Vocabulary(@rdf_prefixes['rm-lod-schema'])
@dbpedia_vocabulary = RDF::Vocabulary.new(@dbpedia_ontology_prefix)


