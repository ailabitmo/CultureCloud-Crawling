# rmgallery.ru HTML data parser generated
# rmgallery_art.xml enrichment
# with DBPedia
# Alexey Andreyev: yetanotherandreyev@gmail.com

require 'rubygems'
require 'nokogiri'

require 'net/http'
require 'uri'
require 'json'

require 'pathname'
require 'colorize'
require 'io/console'


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

@dbPediaSpotlightConfidence=0.2
@dbPediaSpotlightSupport = 0
# DBPedia Spotlight text annotator
# https://github.com/dbpedia-spotlight/dbpedia-spotlight/wiki
def dpdepiaSpotlighAnnotator(inputText,locale)
    case locale
    when "ru" # http://impact.dlsi.ua.es/wiki/index.php/DBPedia_Spotlight
        u = "http://spotlight.sztaki.hu:2227/rest/annotate"
    when "en"
        u = "http://spotlight.sztaki.hu:2222/rest/annotate"
    else
        u = "http://spotlight.dbpedia.org/rest/annotate"
    end
    uri = URI.parse(u)
    headers = {'text' => inputText, 'confidence' => @dbPediaSpotlightConfidence, 'support' => @dbPediaSpotlightSupport}
    spotlighthttp = Net::HTTP.new(uri.host, uri.port)
    response = spotlighthttp.post(uri.path, URI.encode_www_form(headers),{ "Accept" => "text/xml"})
    return response.body
end

def authorsEnrichment()
    # source file #TODO: specify it
    artFile = File.open("rmgallery_art.xml","r")
    doc = Nokogiri::XML(artFile)

    authors = doc.xpath('//section[@label="author"]/sectionItem')

    artXMLenriched = Nokogiri::XML::Builder.new('encoding' => 'UTF-8') { |xml|
        xml.rmGalleryAuthorsEnrichment {
        4.times { |i|
            currentLocale = authors[i].parent.parent["locale"] # FIXME: shame on me
            authorID = authors[i].attributes["id"].text
            authorFullName = authors[i].attributes["label"].text
            annotationText = authors[i].css("bio")[0].text # FIXME: shame on me

            xml.author('id' => authorID, 'fullName' => authorFullName) {
                xml.dbpURI getDPediaUrl(authorFullName,currentLocale)
                xml << Nokogiri::XML(dpdepiaSpotlighAnnotator(annotationText,currentLocale)).xpath("/Annotation").to_xml
            }


        }
        }
    }

    artFileEnriched = File.open("rmgallery_authors_enrichment.xml","w")
    artFileEnriched.write(artXMLenriched.to_xml)
    artFile.close

end

def worksEnrichment()
    # source file #TODO: specify it
    artFile = File.open("rmgallery_art.xml","r")
    doc = Nokogiri::XML(artFile)

    works = doc.xpath('//artItem')

    artXMLenriched = Nokogiri::XML::Builder.new('encoding' => 'UTF-8') { |xml|
        xml.rmGalleryAuthorsEnrichment {
        works.size.times { |i|
            puts "i=#{i}"
            currentLocale = works[i].parent.parent.parent["locale"] # FIXME: shame on me
            workID = works[i].attributes["id"].text
            label = works[i].attributes["label"].text
            annotationText = works[i].css("annotation")[0].text # FIXME
            workDescription = works[i].css("description").text

            xml.work('id' => workID, 'label' => label) {
                xml << Nokogiri::XML(dpdepiaSpotlighAnnotator(label,currentLocale)).xpath("/Annotation").to_xml
                xml << Nokogiri::XML(dpdepiaSpotlighAnnotator(annotationText,currentLocale)).xpath("/Annotation").to_xml
                xml << Nokogiri::XML(dpdepiaSpotlighAnnotator(workDescription,currentLocale)).xpath("/Annotation").to_xml
            }
        }
        }
    }

    artFileEnriched = File.open("rmgallery_works_enrichment.xml","w")
    artFileEnriched.write(artXMLenriched.to_xml)
    artFile.close
end

authorsEnrichment()
#worksEnrichment()
