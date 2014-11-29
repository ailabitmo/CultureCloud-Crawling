require 'nokogiri'
require 'rdf/turtle'
require 'net/http'
require 'unicode'
require 'securerandom'
require 'digest/md5'
require 'russian'
include RDF

puts OWL.to_uri

@prefixes = {
    :rdf => RDF.to_uri,
    :rdfs => RDFS.to_uri,
}
@owl_named_individual = RDF::URI.new('http://www.w3.org/2002/07/owl#NamedIndividual')
@e21_person = RDF::URI.new('http://erlangen-crm.org/current/E21_Person')
@e82_actor_appellation = RDF::URI.new('http://erlangen-crm.org/current/E82_Actor_Appellation')
@p2_has_type = RDF::URI.new('http://erlangen-crm.org/current/P2_has_type')
@p3_has_note = RDF::URI.new('http://erlangen-crm.org/current/P3_has_note')
@p131_is_identified_by = RDF::URI.new('http://erlangen-crm.org/current/P131_is_identified_by')


@graph = RDF::Graph.new(:format => :ttl)


def open_html (url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 1
  http.read_timeout = 10
  begin
    response = http.get(uri.path)
  rescue Net::OpenTimeout
    puts 'Catched new Net::OpenTimeout exception. Press return to retry (recommended) or Ctrl+C to interrupt (all data will be lost in that case).'
    gets
    retry
  end
  response.body
end

def gen_person_uri(person_id)
  RDF::URI.new("http://rm-lod.org/person/#{person_id}")
end
def gen_appellation_uri(person_id)
  RDF::URI.new("http://rm-lod.org/person/#{person_id}/appellation/1")
end

# Crawl targets
@base_url = 'http://rmgallery.ru'
@author_url_ru = @base_url + '/ru/author'
@author_url_en = @base_url + '/en/author'
@css_path = 'div[data-role=controlgroup]'

@authors_ru = Hash.new
@authors_en = Hash.new

puts
puts '== Crawling =='
puts
Nokogiri::HTML(open_html(@author_url_ru)).css(@css_path).css('a').each do |person|
  person_url = person['href']
  person_id = person['href'][4, person['href'].length]
  person_name = person.text.strip
  puts person_name + ' ' + person_url + ' ' + person_id
  @authors_ru[person_id] = person_name
end

Nokogiri::HTML(open_html(@author_url_en)).css(@css_path).css('a').each do |person|
  person_url = person['href']
  person_id = person['href'][4, person['href'].length]
  person_name = person.text.strip
  puts person_name + ' ' + person_url + ' ' + person_id
  @authors_en[person_id] = person_name
end

def get_author_bio(person_id)

end

@authors_ru.each do |person_id, appellation_ru|
  a_ru = appellation_ru
  a_en = @authors_en[person_id]
  unless a_en
    a_en = Russian::transliterate(a_ru)
  end
  puts a_ru + ' ' + a_en
  appellation_uri = gen_appellation_uri(person_id)
  person_uri = gen_person_uri(person_id)

  # Person triplets
  @graph << [person_uri, RDF.type, @e21_person]
  @graph << [person_uri, RDF.type, @owl_named_individual]
  @graph << [person_uri, @p131_is_identified_by, appellation_uri]
  # @graph << [person_uri, @p3_has_note, RDF::Literal.new(bio_ru, :language => :ru)]
  # @graph << [person_uri, @p3_has_note, RDF::Literal.new(bio_en, :language => :en)]

  # Appellation triplets
  @graph << [appellation_uri, RDF.type, @e82_actor_appellation]
  @graph << [appellation_uri, RDF.type, @owl_named_individual]
  @graph << [appellation_uri, RDFS.label, RDF::Literal.new(a_ru, :language => :ru)]
  @graph << [appellation_uri, RDFS.label, RDF::Literal.new(a_en, :language => :en)]
end


puts
puts '== Writing file =='
puts
file = File.new('rm_persons.ttl', 'w')
file.write(@graph.dump(:ttl, :prefixes => @prefixes))
file.close
puts 'Done!'

