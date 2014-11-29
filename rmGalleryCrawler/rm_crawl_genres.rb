require 'nokogiri'
require 'rdf/turtle'
require 'net/http'
require 'unicode'
include RDF

@p2_has_type = RDF::URI.new('http://erlangen-crm.org/current/P2_has_type')

gen_statement = lambda do |genre, object_id|
  genre_uri = RDF::URI.new(genre)
  object_uri = RDF::URI.new("http://rm-lod.org/object/#{object_id}")
  RDF::Statement(object_uri, @p2_has_type, genre_uri)
end

@genre_to_uri = {
    'абстракция' => gen_statement.curry.('http://rm-lod.org/thesauri/abstraction'),
    'аллегория' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x13251'),
    'анималистика' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12469'),
    'батальный жанр' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12993'),
    'библейский сюжет' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12542'),
    'бытовой жанр' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12718'),
    'иллюстрация' => gen_statement.curry.('http://rm-lod.org/thesauri/illustration'),
    'интерьер' => gen_statement.curry.('http://rm-lod.org/thesauri/abstraction'),
    'исторический сюжет' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12859'),
    'карикатура' => gen_statement.curry.('http://rm-lod.org/thesauri/caricature'),
    'мифологический сюжет' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x13025'),
    'натюрморт' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x13409'),
    'пейзаж' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x12934'),
    'портрет' => gen_statement.curry.('http://collection.britishmuseum.org/id/thesauri/x13360'),
    'театральная декорация' => gen_statement.curry.('http://rm-lod.org/thesauri/theatrical_scenery'),
}

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

# Crawl targets
@base_url = 'http://rmgallery.ru'
@genre_url = @base_url + '/ru/genre'
@css_path = 'div[data-role=controlgroup]'
@artworks_css_path = ''


puts
puts '== Crawling =='
puts
Nokogiri::HTML(open_html(@genre_url)).css(@css_path).css('a').each do |genre|
  genre_url = genre['href']
  genre_name = Unicode::downcase(genre.text.strip)
  puts genre_name + ' ' + genre_url
  Nokogiri::HTML(open_html(@base_url + genre['href'])).css(@css_path).css('a').each do |artwork|
    object_id = artwork['href'][4, artwork['href'].length]
    puts '  ' + object_id
    @graph << @genre_to_uri[genre_name].(object_id)
  end
end

puts
puts '== Writing file =='
puts
file = File.new('rm_genres.ttl', 'w')
file.write(@graph.dump(:ttl))
file.close
puts 'Done!'

