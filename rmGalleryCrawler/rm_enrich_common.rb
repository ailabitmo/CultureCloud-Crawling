# encoding: utf-8

require 'colorize'

# Get final Url After Redirects
def getFinalUrl(url)
    return Net::HTTP.get_response(URI(url))['location']
end

# transform wikipedia link to dbpedia resource link
def wikipediaToDBbpedia(wikipedia)
    if ((wikipedia.nil?) or (wikipedia.empty?)) then return nil end
    #TODO: check string with regexp
    if !(wikipedia.start_with?("http://en.wikipedia.org/wiki/")) then return nil end    
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

    if foundWikiData.nil? then return nil end
    foundWikiDataSize = foundWikiData.size
    foundWikiDataSize.size.times { |i|
        #puts (foundWikiData[i])
        currentResult = ""
        currentResult = URI.unescape(foundWikiData[i]) unless foundWikiData[i].nil?
        puts "#{(i+1).to_s}.: #{currentResult}".colorize(:color => (i==0)?:yellow : :light_yellow)
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
        return nil
    else
        getDPediaUrl(answer,locale)
    end
end

@dbPediaSpotlightConfidence=0.2
@dbPediaSpotlightSupport = 20
# DBPedia Spotlight text annotator
# https://github.com/dbpedia-spotlight/dbpedia-spotlight/wiki
def dbpepiaSpotlightAnnotator(inputText,locale,acceptAttrib="text/html")
    case locale
    when :ru # http://impact.dlsi.ua.es/wiki/index.php/DBPedia_Spotlight
        u = "http://spotlight.sztaki.hu:2227/rest/annotate" #"http://ru.spotlight.dbpedia.org/rest/annotate"
    when :en
        u = "http://spotlight.sztaki.hu:2222/rest/annotate" #"http://en.spotlight.dbpedia.org/rest/annotate"
    else
        u = "http://spotlight.dbpedia.org/rest/annotate"
    end
    uri = URI.parse(u)
    headers = {'text' => inputText, 'confidence' => @dbPediaSpotlightConfidence, 'support' => @dbPediaSpotlightSupport}
    spotlighthttp = Net::HTTP.new(uri.host, uri.port)
    begin
        response = spotlighthttp.post(uri.path, URI.encode_www_form(headers),{ "Accept" => acceptAttrib})
    rescue Exception => e
        puts "#{e.message}. Press return to retry."
        # gets
        retry
    end
    #result = Nokogiri::HTML(response.body).xpath("//html/body/div").first.inner_html.gsub(/http:\/\/(ru.|)dbpedia.org\/resource\//,URI.unescape("http://heritage.vismart.biz/resource/?uri="+'\0'))
    return response.body
end
