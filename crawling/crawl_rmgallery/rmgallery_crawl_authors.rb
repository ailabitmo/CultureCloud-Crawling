require 'nokogiri'
require 'rdf/turtle'
require 'net/http'
require 'unicode'
require 'securerandom'
require 'digest/md5'
require 'russian'
include RDF

def open_html (url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 1
  http.read_timeout = 10
  begin
    response = http.get(uri.path)
  rescue Net::OpenTimeout
    puts 'Caught new Net::OpenTimeout exception.'
    retry
  end
  response.body
end

@artwork_ownerships = RDF::Graph.load('../results/rmgallery_artwork_ownerships.ttl')

def crawl_bio(object_id)
  bio = Hash.new
  Nokogiri::HTML(open_html("http://rmgallery.ru/en/#{object_id}")).\
      css('div[data-role=collapsible]').each do |collapsible|
    if collapsible.css('h3').text == "Author's Biogrphy"
      b = collapsible.css('p').text
      bio['en'] = b unless b.empty?
    end
  end
  Nokogiri::HTML(open_html("http://rmgallery.ru/ru/#{object_id}")).\
      css('div[data-role=collapsible]').each do |collapsible|
    if collapsible.css('h3').text == 'Биография автора'
      b = collapsible.css('p').text
      bio['ru'] = b unless b.empty?
    end
  end
  bio
end

def author_of_crawled_artwork?(person_id)
  q = RDF::Query::Pattern.new(:s, RDF::URI.new('http://erlangen-crm.org/current/P14_carried_out_by'),
                              RDF::URI.new("http://rm-lod.org/person/#{person_id}"));
  q.execute(@artwork_ownerships).size > 0
end

def get_author_bio(person_id)
  q = RDF::Query.new({
                         :obj => {
                             RDF::URI.new('http://erlangen-crm.org/current/P14_carried_out_by') =>
                                 RDF::URI.new("http://rm-lod.org/person/#{person_id}")
                         }})
  production = q.execute(@artwork_ownerships).first[:obj].to_s
  object_id = /http:\/\/rm-lod.org\/object\/([0-9]+)\/production\/?/.match(production)[1]
  crawl_bio(object_id)
end

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
@graph_notes = RDF::Graph.new(:format => :ttl)

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
  person_url = person['href'].strip
  person_id = person['href'][4, person['href'].length].strip
  next unless author_of_crawled_artwork?(person_id)
  person_name = person.text.strip
  puts person_name + ' ' + person_url + ' ' + person_id
  @authors_ru[person_id] = person_name
end

Nokogiri::HTML(open_html(@author_url_en)).css(@css_path).css('a').each do |person|
  person_url = person['href'].strip
  person_id = person['href'][4, person['href'].length].strip
  next unless author_of_crawled_artwork?(person_id)
  person_name = person.text.strip
  puts person_name + ' ' + person_url + ' ' + person_id
  @authors_en[person_id] = person_name
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
  bio = get_author_bio(person_id)
  @graph_notes << [person_uri, @p3_has_note, RDF::Literal.new(bio['ru'], :language => :ru)] if bio['ru']
  @graph_notes << [person_uri, @p3_has_note, RDF::Literal.new(bio['en'], :language => :en)] if bio['en']

  # Appellation triplets
  @graph << [appellation_uri, RDF.type, @e82_actor_appellation]
  @graph << [appellation_uri, RDF.type, @owl_named_individual]
  @graph << [appellation_uri, RDFS.label, RDF::Literal.new(a_ru, :language => :ru)]
  @graph << [appellation_uri, RDFS.label, RDF::Literal.new(a_en, :language => :en)]
  @graph << [person_uri, RDFS.label, RDF::Literal.new(a_ru, :language => :ru)]
  @graph << [person_uri, RDFS.label, RDF::Literal.new(a_en, :language => :en)]
end

puts
puts '== Writing file =='
puts
file = File.new('../results/rmgallery_persons.ttl', 'w')
file.write(@graph.dump(:ttl, :prefixes => @prefixes))
file.close
puts
puts '== Writing notes =='
puts
file = File.new('../results/rmgallery_persons_notes.ttl', 'w')
file.write(@graph_notes.dump(:ttl, :prefixes => @prefixes))
file.close
puts 'Done!'

