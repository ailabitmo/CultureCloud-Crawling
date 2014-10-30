# rmgallery.ru HTML data parser generated
# rmgallery_art.xml to turtle-rdf data parser
# with DBPedia enrichment
# Alexey Andreyev: yetanotherandreyev@gmail.com

require 'rubygems'

require 'net/http'
require 'uri'
require 'json'

require 'pathname'
require 'colorize'
require 'io/console'

require 'nokogiri'
require 'rdf/turtle'


# TODO: cotribute to dbpediafinder: https://github.com/moustaki/dbpediafinder/
# TODO: images rdf
# TODO: genres rdf
# TODO: types rdf

# Get final Url After Redirects
def getFinalUrl(url)
  return Net::HTTP.get_response(URI(url))['location']
end

# transform wikipedia link to dbpedia resource link
def wikipediaToDBbpedia(wikipedia)
  if ((wikipedia.nil?) or (wikipedia.empty?)) then return nil end
  #TODO: check string with regexp
  url_key = wikipedia.split('/').last
  return "http://dbpedia.org/resource/" + url_key
end

# Search for wikipedia article links
# by title with wikipedia search api
def wikipediaSearch(label, locale="en")
  hostUrl = "http://#{locale}.wikipedia.org/"
  wikipedia_url_s = "#{hostUrl}w/api.php?action=query&format=json&list=search&srsearch=#{URI.encode(label)}&srprop="
  url = URI.parse(wikipedia_url_s)
  if @proxy
    h = Net::HTTP::Proxy(@proxy.host, @proxy.port).new(url.host, url.port)
  else
    h = Net::HTTP.new(url.host, url.port)
  end
  h.open_timeout = 1
  h.read_timeout = 1
  h.start do |h|
    begin
      res = h.get(url.path + "?" + url.query)
    rescue Exception => e
      puts "#{e.message}. Press return to retry."
      gets
      retry
    end
    json = JSON.parse(res.body)
    results = json["query"]["search"].map { |result|
      getFinalUrl(URI.encode(hostUrl+"wiki/"+result["title"]))
    }
    if (results.empty?) then
      suggestion = json["query"]["searchinfo"]["suggestion"]
      if !(suggestion.nil?) then
	return wikipediaSearch(suggestion,locale)
      else
	puts "Result for not found. Enter new search string or return to skip"
	answer = gets
        if (answer=="\n") then
          puts "skipped"
	  return nil
	else 
	  wikipediaSearch(answer,locale)
	end
      end
    else
      return results
    end
  end
end

# Search for dbpedia resource link by title
def getDPediaUrl(searchString, locale)
  puts "Searching for: #{searchString} in #{locale}-wiki...".blue.on_red
  puts
  foundWikiData = wikipediaSearch(searchString, locale)
  puts "Search results:"
  
  if foundWikiData.nil? then return end

  foundWikiDataSize = foundWikiData.size
  foundWikiDataSize.size.times { |i|                           
    puts "#{(i+1).to_s}.: #{foundWikiData[i]}".colorize(:color => (i==0)?:yellow : :light_yellow)             
  }
  puts
  puts "Is first result ok? Enter:"
  puts "Return to accept first current result"
  puts "Number of wikipedia result (will be transformed to DBPedia resource)"
  puts "New search string to specify and search again"
  puts "- symbol to skip current artist"
  answer = gets
  answerToI = answer.to_i
  if (answer=="\n") then
    puts "Got it!"
    return wikipediaToDBbpedia(foundWikiData[0]) # http://dbpedia.org/resource/...
  puts answerToI  
  elsif ((answerToI!=0) and (answerToI<foundWikiDataSize))
    return wikipediaToDBbpedia(foundWikiData[answerToI-1])
  elsif (answer=="-\n")
    return 
  else
    getDPediaUrl(answer,locale)
  end
end

# DBPedia Spotlight text annotator
# https://github.com/dbpedia-spotlight/dbpedia-spotlight/wiki
def dpdepiaSpotlighAnnotator(inputText)
  u = URI.encode("http://spotlight.dbpedia.org/rest/annotate")
  uri = URI.parse(u)
  puts "INPUT TEXT:"
  puts inputText
  url = URI("http://spotlight.dbpedia.org/rest/annotate")
  res = Net::HTTP.post_form(url, {'text' => inputText, 'confidence' => @dbPediaSpotlightConfidence, 'support' => @dbPediaSpotlightSupport})
  res['Accept'] = "text/xml"
  # puts res.body
  return res.body
end


# Authors rdf generator:

@proxy = URI.parse(ENV['HTTP_PROXY']) if ENV['HTTP_PROXY']

#TODO: ask for this values:
@dbPediaSpotlightConfidence = 0.2
@dbPediaSpotlightSupport = 20

consoleWidth = IO.console.winsize[1]

# source file #TODO: specify it
artFile = File.open("rmgallery_art.xml","r")
doc = Nokogiri::XML(artFile)

authors = doc.xpath('//section[@label="author"]/sectionItem/fullName')
authorsSize = authors.size
puts "Found #{authors.size} authors"

# cidocCRM. TODO: choose version
cidocCRM = RDF::Vocabulary.new('http://www.cidoc-crm.org/rdfs/cidoc_crm_v5.1-draft-2014March.rdfs#')
rdf_prefixes = {
  'cidoc-crm' =>  "http://www.cidoc-crm.org/rdfs/cidoc_crm_v5.1-draft-2014March.rdfs#",
  rdf:  "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
  dbp:  "http://dbpedia.org/resource/",
  owl: "http://www.w3.org/2002/07/owl#",
  ourprefix: "http://oursite.org/resource/"
}
owlVocabulary = RDF::Vocabulary.new(rdf_prefixes['owl'])

# authors file # TODO: specify it
rmgallery_authors_filepath = "rmgallery_authors.ttl"
if !(File.file?(rmgallery_authors_filepath)) then
  puts "#{rmgallery_authors_filepath} was not found in working dir"
else
  puts "#{rmgallery_authors_filepath} was found in working dir"
  authorsFile = File.open(rmgallery_authors_filepath,"r")
  previousAuthorsGraph = RDF::Graph.load(authorsFile) # FIXME: check is data ok
  authorsFile.close
end

authorsGraph = RDF::Graph.new(:format => :ttl, :prefixes => rdf_prefixes)

if !(previousAuthorsGraph.nil?) then
  authorsGraph = previousAuthorsGraph
end

authorsSize.times { |i|
  currentLocale = authors[i].parent.parent.parent["locale"] # FIXME: shame on me                  
  authorFullName = authors[i].text 
  authorFullNameLiteral = RDF::Literal.new(authorFullName, :language => currentLocale)                  
  if (authorsGraph.query([nil, cidocCRM[:P1_is_identified_by], authorFullNameLiteral]).empty?) then
    authorURI =  RDF::URI.new(authorFullName) #FIXME: generate real URI             
    dbPediaResUrl = getDPediaUrl(authors[i].text, currentLocale)
    dbPediaURI = RDF::URI.new(dbPediaResUrl)
    authorsGraph << [authorURI, owlVocabulary[:sameAs], dbPediaURI]              
    authorsGraph.insert([authorURI, cidocCRM[:P2_has_type], cidocCRM.E21_Person])
                
    authorsGraph << [authorURI, cidocCRM[:P1_is_identified_by], authorFullNameLiteral]
    annotationText = authors[i].parent.css("bio")[0].text     
    authorsGraph << [authorURI, cidocCRM[:P3_has_note], annotationText]         
    # puts dpdepiaSpotlighAnnotator(annotationText)                
  end
                
                  
  percentage = "authors processed: #{i+1} of #{authorsSize} "                
  puts percentage+"#"*(consoleWidth-percentage.length)
                  
  authorsFile = File.new("rmgallery_authors.ttl","w")      
  authorsFile.write(authorsGraph.dump(:ttl, :prefixes => rdf_prefixes))
  authorsFile.close      
}



artFile.close