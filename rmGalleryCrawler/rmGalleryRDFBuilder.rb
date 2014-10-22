# rmgallery.ru HTML data parser
# Alexey Andreyev: yetanotherandreyev@gmail.com

=begin
This software is licensed under the "Anyone But Richard M Stallman"
(ABRMS) license, described below. No other licenses may apply.


--------------------------------------------
The "Anyone But Richard M Stallman" license
--------------------------------------------

Do anything you want with this program, with the exceptions listed
below under "EXCEPTIONS".

THIS SOFTWARE IS PROVIDED "AS IS" WITH NO WARRANTY OF ANY KIND.

In the unlikely event that you happen to make a zillion bucks off of
this, then good for you; consider buying a homeless person a meal.


EXCEPTIONS
----------

Richard M Stallman (the guy behind GNU, etc.) may not make use of or
redistribute this program or any of its derivatives.

P.S.: just messing :)
=end


require 'rubygems'
require 'colorize'
require 'uri'
require 'json'
require 'net/http'
require 'nokogiri'
require 'io/console'

# TODO: cotribute to dbpediafinder: https://github.com/moustaki/dbpediafinder/
# TODO: images rdf
# TODO: genres rdf
# TODO: types rdf

@proxy = URI.parse(ENV['HTTP_PROXY']) if ENV['HTTP_PROXY']

def wikipediaToDBbpedia(wikipedia)
  url_key = wikipedia.split('/').last
  return "http://dbpedia.org/resource/" + url_key
end

def wikipediaSearch(label, locale="en")
  hostUrl = "http://#{locale}.wikipedia.org/"
  wikipedia_url_s = "#{hostUrl}w/api.php?action=query&format=json&list=search&srsearch=#{URI.encode(label)}&srprop="
  url = URI.parse(wikipedia_url_s)
  if @proxy
    h = Net::HTTP::Proxy(@proxy.host, @proxy.port).new(url.host, url.port)
  else
    h = Net::HTTP.new(url.host, url.port)
  end
  h.start do |h|
    res = h.get(url.path + "?" + url.query)
    json = JSON.parse(res.body)
    results = json["query"]["search"].map { |result| hostUrl+"wiki/"+URI.encode(result["title"]) }
    if (results.empty?) then
      suggestion = json["query"]["searchinfo"]["suggestion"]
      if !(suggestion.empty?) then
	return wikipediaSearch(suggestion,locale)
      end
    else
      return results
    end
  end
end

def getDPediaName(searchString, disambiguation="")
  puts "Searching for: #{searchString}...".blue.on_red.blink
  puts
  foundWikiData = wikipediaSearch(searchString)
  foundWikiDataSize = foundWikiData.size
  foundWikiDataSize.size.times { |i|                           
    puts "#{(i+1).to_s}.: #{foundWikiData[i]}".colorize(:color => (i==0)?:yellow : :light_yellow)             
  }
  puts
  puts "Is first result ok? Enter:"
  puts "Return to accept first current result"
  puts "Number of wikipedia result (will be transformed to DBPedia resource)"
  puts "New search string to specify it"
  puts "- symbol to return empty string"
  answer = gets
  answerToI = answer.to_i
  if (answer=="\n") then
    puts "Got it!"
    return wikipediaToDBbpedia(foundWikiData[0]) # http://dbpedia.org/resource/...
  puts answerToI  
  elsif ((answerToI!=0) and (answerToI<foundWikiDataSize))
    return wikipediaToDBbpedia(foundWikiData[answerToI-1])
  elsif (answer=="-\n")
    return ""
  else
    getDPediaName(answer)
  end
end

artFile = File.open("rmgallery_art.xml","r")
doc = Nokogiri::XML(artFile)

consoleWidth = IO.console.winsize[1]

authors = doc.xpath('//section[@label="author"]/sectionItem/fullName')
authorsSize = authors.size
puts "Found #{authors.size} authors"
puts authors[0].parent.parent.parent["locale"]
authorsSize.times { |i|
  puts getDPediaName(authors[i].text, authors[i].parent.parent.parent["locale"])
  
  percentage = "authors process: #{i+1} of #{authorsSize} "                
  puts percentage+"#"*(consoleWidth-percentage.length)                
}
artFile.close