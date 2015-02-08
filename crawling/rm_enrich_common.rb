# encoding: utf-8

require 'colorize'

# Get final Url After Redirects
def get_final_url(url)
    Net::HTTP.get_response(URI(url))['location']
end

# transform wikipedia link to dbpedia resource link
def wikipedia_to_dbpedia(wikipedia)
    if (wikipedia.nil?) or (wikipedia.empty?)
        return nil
    end
    #TODO: check string with regexp
    unless wikipedia.start_with?("http://en.wikipedia.org/wiki/")
        return nil
    end
    url_key = wikipedia.split('/').last
    "http://dbpedia.org/resource/" + url_key
end

# Search for wikipedia article links
# by title with wikipedia search api
def wikipedia_search(label, locale="en")
    host_url = "http://#{locale}.wikipedia.org/"
    wikipedia_url_s = "#{host_url}w/api.php?action=query&format=json&list=search&srsearch=#{URI.encode(label)}&srprop="
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
          get_final_url(URI.encode(host_url+"wiki/"+result["title"]))
        }
        if results.empty?
            suggestion = json["query"]['searchinfo']["suggestion"]
            if !(suggestion.nil?)
                return wikipedia_search(suggestion,locale)
            else
                puts "Result for not found. Enter new search string or return to skip"
                answer = gets
                if answer=="\n"
                    puts "skipped"
                    return nil
                else
                    wikipedia_search(answer,locale)
                end
            end
        else
            return results
        end
    end
end

# Search for dbpedia resource link by title
def get_dbpedia_url(search_string, locale)
    puts "Searching for: #{search_string} in #{locale}-wiki...".blue.on_red
    puts
    found_wiki_data = wikipedia_search(search_string, locale)
    puts "Search results:"

    if found_wiki_data.nil?
    then
        return nil
    end
    found_wiki_data_size = found_wiki_data.size
    found_wiki_data_size.size.times { |i|
        #puts (found_wiki_data[i])
        current_result = ""
        current_result = URI.unescape(found_wiki_data[i]) unless found_wiki_data[i].nil?
        puts "#{(i+1).to_s}.: #{current_result}".colorize(:color => (i==0)?:yellow : :light_yellow)
    }
    puts
    puts "Is first result ok? Enter:"
    puts "Return to accept first current result"
    puts "Number of wikipedia result (will be transformed to DBPedia resource)"
    puts "New search string to specify and search again"
    puts "- symbol to skip current artist"
    answer = gets
    answer_to_i = answer.to_i
    if answer=="\n"
        puts "Got it!"
        wikipedia_to_dbpedia(found_wiki_data[0]) # http://dbpedia.org/resource/...
    elsif (answer_to_i!=0) and (answer_to_i<found_wiki_data_size)
        wikipedia_to_dbpedia(found_wiki_data[answer_to_i-1])
    elsif answer=="-\n"
        nil
    else
        get_dbpedia_url(answer,locale)
    end
end

@dbpedia_spotlight_confidence=0.2
@dbpedia_spotlight_support = 20
# DBPedia Spotlight text annotator
# https://github.com/dbpedia-spotlight/dbpedia-spotlight/wiki
def dbpepia_spotlight_annotator(input_text,locale,accept_attrib="text/html")
    case locale
    when :ru # http://impact.dlsi.ua.es/wiki/index.php/DBPedia_Spotlight
        u = "http://spotlight.sztaki.hu:2227/rest/annotate" #"http://ru.spotlight.dbpedia.org/rest/annotate"
    when :en
        u = "http://spotlight.sztaki.hu:2222/rest/annotate" #"http://en.spotlight.dbpedia.org/rest/annotate"
    else
        u = "http://spotlight.dbpedia.org/rest/annotate"
    end
    uri = URI.parse(u)
    headers = {'text' => input_text, 'confidence' => @dbpedia_spotlight_confidence, 'support' => @dbpedia_spotlight_support}
    spotlight_http = Net::HTTP.new(uri.host, uri.port)
    begin
        response = spotlight_http.post(uri.path, URI.encode_www_form(headers),{ "Accept" => accept_attrib})
    rescue Exception => e
        puts "#{e.message}. Press return to retry."
        # gets
        retry
    end
    #result = Nokogiri::HTML(response.body).xpath("//html/body/div").first.inner_html.gsub(/http:\/\/(ru.|)dbpedia.org\/resource\//,URI.unescape("http://heritage.vismart.biz/resource/?uri="+'\0'))
    response.body
end
