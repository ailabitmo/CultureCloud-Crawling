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

ourAuthors={}
 
bingo = 0
@persons_sameas_ttl = RDF::Graph.load('../rm_persons_sameas.ttl')
#puts (RDF::Query::Pattern.new(:s, OWL.sameAs, RDF::URI.new("http://dbpedia.org/resource/Sergey_Ivanov_(painter)")).execute(@persons_sameas_ttl).empty?)
#gets

@host_url = "http://www.wikiart.org"
@by_alphabet_suffix = @host_url + "/en/Alphabet"
by_alphabet_array = ('a'..'z').to_a + ['3','-']
by_alphabet_array.each { |letter|
  current_letter_url= @by_alphabet_suffix+"/"+letter
  puts current_letter_url                       
  Nokogiri::HTML(open_html(current_letter_url)).css("body").css("div[class=\"Artist mr-20\"]").css("div[class=\"search-item fLeft\"]").each { |artist_html|
    artist_url = @host_url + artist_html.css("div.pozRel a").first['href'].to_s
    puts artist_url
    if UrlAvailable?(artist_url)
    then
        a_first = Nokogiri::HTML(open_html(artist_url)).css("body").css("td.fa11 a").first                                                                                                                                  
        wikipedia_url = a_first['href'] unless a_first.nil?
        if !wikipedia_url.nil?
        then                                                                                                                                    
            puts wikipedia_url                                                                                                                                    
            dbp_url = wikipediaToDBbpedia(wikipedia_url)                                                                                                                               
            puts RDF::URI.new(dbp_url)                                                                                                                                        
            if !(RDF::Query::Pattern.new(:s, OWL.sameAs,RDF::URI.new(dbp_url)).execute(@persons_sameas_ttl).empty?)
            then
            puts "our author!"
            ourAuthors[dbp_url]={"wikiart_url:"=>artist_url}                                                                                                                               
            #puts dbp_url                                                                                                                                      
            bingo+=1                                                                                                            
            end
        end                                                                                                                                    
    end                                                                                                                                        
  }                   
}     
puts bingo
file = File.new('ourAuthors.json', 'w')
file.write(ourAuthors.to_json)
file.close