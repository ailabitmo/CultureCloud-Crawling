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

our_authors={}
 
authors_number = 0
# noinspection SpellCheckingInspection
@persons_sameas_ttl = RDF::Graph.load('../results/rmgallery.ru/rm_persons_sameas.ttl')
#puts (RDF::Query::Pattern.new(:s, OWL.sameAs, RDF::URI.new("http://dbpedia.org/resource/Sergey_Ivanov_(painter)")).execute(@persons_sameas_ttl).empty?)
#gets

@host_url = 'http://www.wikiart.org'
@by_alphabet_suffix = @host_url + "/en/Alphabet"
by_alphabet_array = ('a'..'z').to_a + ['3','-']
by_alphabet_array.each { |letter|
  current_letter_url= @by_alphabet_suffix+"/"+letter
  puts current_letter_url
  Nokogiri::HTML(open_html(current_letter_url)).css("body").css("div[class=\"Artist mr-20\"]").css("div[class=\"search-item fLeft\"]").each { |artist_html|
    artist_url = @host_url + artist_html.css("div.pozRel a").first['href'].to_s
    puts artist_url
    if url_available?(artist_url)
    then
      a_first = Nokogiri::HTML(open_html(artist_url)).css("body").css("td.fa11 a").first
      wikipedia_url = ''
      wikipedia_url = a_first['href'] unless a_first.nil?
      unless wikipedia_url.nil?
      then
        # puts wikipedia_url
        dbp_url = wikipedia_to_dbpedia(wikipedia_url)
        puts RDF::URI.new(dbp_url)
        unless RDF::Query::Pattern.new(:s, OWL.sameAs, RDF::URI.new(dbp_url)).execute(@persons_sameas_ttl).empty?
        then
          puts "our author!"
          wikiart_url_string = 'wikiart_url'
          our_authors[dbp_url]={wikiart_url_string => artist_url}
          #puts dbp_url
          authors_number+=1
        end
      end
    end
  }
}     
puts authors_number
file = File.new('our_authors.json', 'w')
file.write(our_authors.to_json)
file.close