require './rm_crawl_common.rb'
require 'nokogiri'
require 'rdf/turtle'
require 'net/http'
require 'unicode'
require 'set'
include RDF

@ecrmPrefix = "http://erlangen-crm.org/current/"
@ecrmVocabulary = RDF::Vocabulary.new(@ecrmPrefix)

@p2_has_type = RDF::URI.new('http://erlangen-crm.org/current/P2_has_type')

gen_statement = lambda do |genre, object_id|
  genre_uri = RDF::URI.new(genre)
  object_uri = RDF::URI.new("http://culturecloud.ru/id/object/#{object_id}")
  RDF::Statement(object_uri, @p2_has_type, genre_uri)
end

@genre_to_uri = {
    'абстракция' => gen_statement.curry.('http://culturecloud.ru/id/thesauri/abstraction'),
    'аллегория' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x13251'),
    'анималистика' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12469'),
    'батальный жанр' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12993'),
    'библейский сюжет' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12542'),
    'бытовой жанр' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12718'),
    'иллюстрация' => gen_statement.curry.('http://culturecloud.ru/id/thesauri/illustration'),
    'интерьер' => gen_statement.curry.('http://culturecloud.ru/id/thesauri/abstraction'),
    'исторический сюжет' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12859'),
    'карикатура' => gen_statement.curry.('http://culturecloud.ru/id/thesauri/caricature'),
    'мифологический сюжет' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x13025'),
    'натюрморт' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x13409'),
    'пейзаж' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12934'),
    'портрет' => gen_statement.curry.('http://culturecloud.ru/id/thesauri/portrait'),
    'театральная декорация' => gen_statement.curry.('http://culturecloud.ru/id/thesauri/theatrical_scenery'),
}

@genres_hash = {
    'абстракция' => RDF::URI.new('http://culturecloud.ru/id/thesauri/abstraction'),
    'аллегория' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x13251'),
    'анималистика' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12469'),
    'батальный жанр' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12993'),
    'библейский сюжет' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12542'),
    'бытовой жанр' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12718'),
    'иллюстрация' => RDF::URI.new('http://culturecloud.ru/id/thesauri/illustration'),
    'интерьер' => RDF::URI.new('http://culturecloud.ru/id/thesauri/abstraction'),
    'исторический сюжет' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12859'),
    'карикатура' => RDF::URI.new('http://culturecloud.ru/id/thesauri/caricature'),
    'мифологический сюжет' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x13025'),
    'натюрморт' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x13409'),
    'пейзаж' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12934'),
    'портрет' => RDF::URI.new('http://culturecloud.ru/id/thesauri/portrait'),
    'театральная декорация' => RDF::URI.new('http://culturecloud.ru/id/thesauri/theatrical_scenery'),
}

@graph = RDF::Graph.new(:format => :ttl)
@graph_titles = RDF::Graph.new(:format => :ttl)

def open_html (url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 1
  http.read_timeout = 10
  begin
    response = http.get(uri.path)
  rescue Net::OpenTimeout
    puts 'Catched new Net::OpenTimeout exception. Press return to retry (recommended) or Ctrl+C to interrupt (all data will be lost in that case).'
    retry
  end
  response.body
end


@artwork_ids = (Proc.new {
  artworks_ids = Set.new
  RDF::Query::Pattern.new(:s, RDF::URI.new('http://erlangen-crm.org/current/P14_carried_out_by'), :o).
      execute(RDF::Graph.load('rm_artwork_ownerships.ttl')).each do |statement|
    artworks_ids << /\d+/.match(statement.subject)[0]
  end
  artworks_ids
}).call

# Crawl targets
@base_url = 'http://rmgallery.ru'
@genre_url = @base_url + '/ru/genre'
@css_path = 'div[data-role=controlgroup]'
@artworks_css_path = ''


puts
puts '== Crawling =='
puts
Nokogiri::HTML(open_html(@genre_url)).css(@css_path).css('a').each do |genre|
  genre_url = genre['href'].strip
  genre_name = Unicode::downcase(genre.text.strip)
  puts genre_name + ' ' + genre_url
  Nokogiri::HTML(open_html(@base_url + genre['href'])).css(@css_path).css('a').each do |artwork|
    object_id = artwork['href'][4, artwork['href'].length].strip
    next unless @artwork_ids.include?(object_id)
    puts '  ' + object_id
    @graph << @genre_to_uri[genre_name].(object_id)
  end
end

puts
puts '== Writing genres translations =='
puts

@genres_hash.each { |title,uri|
  @graph_titles << [uri,RDF.type,SKOS.Concept]
  @graph_titles << [uri,RDF.type,@ecrmVocabulary['E55_Type']]                  
  @graph_titles << [uri,SKOS.prefLabel,RDF::Literal.new(title, :language => :ru)]  
}

file = File.new('rm_genres_titles.ttl', 'w')
file.write(@graph_titles.dump(:ttl, :prefixes => @rdf_prefixes))
file.close


puts
puts '== Writing file =='
puts
file = File.new('rm_genres.ttl', 'w')
file.write(@graph.dump(:ttl))
file.close
puts 'Done!'

