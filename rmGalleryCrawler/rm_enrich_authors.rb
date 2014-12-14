# encoding: utf-8

require 'rubygems'

require 'net/http'
require 'uri'
require 'json'
require 'set'

#require 'pathname'
require 'colorize'
require 'io/console'

require 'nokogiri'
require 'rdf/turtle'
include RDF # Additional built-in vocabularies: http://rdf.greggkellogg.net/yard/RDF/Vocabulary.html
#require 'securerandom'


def openHtml(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 1
  http.read_timeout = 10
  begin
    response = http.get(uri.path)
  rescue Net::OpenTimeout
    puts 'Catched new Net::OpenTimeout exception. Press return to retry (recommended) or Ctrl+C to interrupt (the data will be lost in that case).'
    retry
  end
  return response.body
end


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
def dbpepiaSpotlighAnnotator(inputText,locale)
    case locale
    when "ru" # http://impact.dlsi.ua.es/wiki/index.php/DBPedia_Spotlight
        u = "http://ru.spotlight.dbpedia.org/rest/annotate"# "http://spotlight.sztaki.hu:2227/rest/annotate"
    when "en"
        u = "http://en.spotlight.dbpedia.org/rest/annotate"# "http://spotlight.sztaki.hu:2222/rest/annotate"
    else
        u = "http://spotlight.dbpedia.org/rest/annotate"
    end
    uri = URI.parse(u)
    headers = {'text' => inputText, 'confidence' => @dbPediaSpotlightConfidence, 'support' => @dbPediaSpotlightSupport}
    spotlighthttp = Net::HTTP.new(uri.host, uri.port)
    begin
        response = spotlighthttp.post(uri.path, URI.encode_www_form(headers),{ "Accept" => "application/xhtml+xml"})
    rescue Exception => e
        puts "#{e.message}. Press return to retry."
        gets
        retry
    end
    return response.body
end

BilingualLabel = Struct.new(:en, :ru)
@localeLabels = BilingualLabel.new("en","ru")

@rdf_prefixes = {
    'ecrm' =>  "http://erlangen-crm.org/current/",
    :rdf => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :dbp =>  "http://dbpedia.org/resource/", # Do we really need it? Resources depend from locale
    :owl => OWL.to_uri,
    'rm-lod' => "http://rm-lod.org/",
    'rm-lod-schema' => "http://rm-lod.org/schema/",
}

@ecrmVocabulary = RDF::Vocabulary.new(@rdf_prefixes['ecrm'])
@rmlodVocabulary = RDF::Vocabulary.new(@rdf_prefixes['rm-lod-schema'])

@persons_ttl = RDF::Graph.load('rm_persons.ttl')

puts "ok go"

persons = Set.new
personsLabels = Hash.new
personsNotes = Hash.new
RDF::Query::Pattern.new(:s, RDF.type,@ecrmVocabulary[:E21_Person]).execute(@persons_ttl).each { |e21person_statement|
    personURI = e21person_statement.subject
    personLabel = Hash.new
    RDF::Query::Pattern.new(personURI, RDFS.label,:o).execute(@persons_ttl).each { |label_statement|
        personLabel[label_statement.object.language]=label_statement.object.to_s
    }
    personNote = Hash.new
    RDF::Query::Pattern.new(personURI, @ecrmVocabulary[:P3_has_note],:o).execute(@persons_ttl).each { |note_statement|
        personNote[note_statement.object.language]=note_statement.object.to_s
    }
    personsLabels[personURI]=personLabel
    personsNotes[personURI]=personNote
    persons << personURI
}

persons_sameas_ttl_path = "rm_persons_sameas.ttl"
if (File.exists?(persons_sameas_ttl_path))
then
    persons_sameas_ttl = RDF::Graph.load(persons_sameas_ttl_path)
else
    persons_sameas_ttl = RDF::Graph.new(:format => :ttl)
end
persons_notes_ttl_path = "rm_persons_annotations.ttl"
if (File.exists?(persons_notes_ttl_path))
then
    persons_notes_ttl = RDF::Graph.load(persons_notes_ttl_path)
else
    persons_notes_ttl = RDF::Graph.new(:format => :ttl)
end

persons.to_a.each { |personURI|
    if (RDF::Query::Pattern.new(personURI, OWL.sameAs,:o).execute(persons_sameas_ttl).empty?)
    then
        new_dbp_uri = getDPediaUrl(personsLabels[personURI][:ru],"ru")
        if (new_dbp_uri.nil?)
        then
            new_dbp_uri = getDPediaUrl(personsLabels[personURI][:en],"en")
        end
        if !(new_dbp_uri.nil?)
        then
            persons_sameas_ttl << [personURI, OWL.sameAs,new_dbp_uri]
        else
            puts "found nothing for #{personURI}"
        end
    else
        puts "#{personURI} already linked with dbp"
    end

=begin
    if (RDF::Query::Pattern.new(personURI, @rmlodVocabulary[:hasAnnotation], :o).execute(persons_notes_ttl).empty?)
    then
        personsNotes[personURI].each { |locale,note|
            annotation=dbpepiaSpotlighAnnotator(note,locale)
            persons_notes_ttl << [personURI, @rmlodVocabulary[:hasAnnotation], RDF::Literal.new(annotation.force_encoding('utf-8'), :language => locale)] unless annotation.empty?
        }
    end
=end    
}

puts '== saving data =='
file = File.new(persons_sameas_ttl_path, 'w')
file.write(persons_sameas_ttl.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== saving data =='
file = File.new(persons_notes_ttl_path, 'w')
file.write(persons_notes_ttl.dump(:ttl, :prefixes => @rdf_prefixes))
file.close
=begin

def authorsEnrichmentRdfGenerator
    authorsPrefix = "#{@rdf_prefixes["rm-lod"]}person/"
    idsArray = (Proc.new {
        ids = Set.new
        RDF::Reader.open('rm_persons.ttl') do |reader|
            reader.each_statement do |s|
                id = /^http:\/\/rm\-lod\.org\/person\/(\d+)$/.match(s.subject)
                ids << id[1] unless id.nil?
            end
        end
        ids
    }).call

    authorsGraph = RDF::Graph.new(:format => :ttl, :prefixes => @rdf_prefixes)

    authorsEnrichmentXMLFile = File.open("rmgallery_authors_enrichment.xml","r")
    doc = Nokogiri::XML(authorsEnrichmentXMLFile)

    idsArray.each { |authorId|
        authorURI =  RDF::URI.new("#{authorsPrefix}#{authorId}")
        authorNode = doc.xpath("/rmGalleryAuthorsEnrichment/author[@id='#{authorId}']")

        dbpResUrl = authorNode.css("dbpURI").text # FIXME: want to use xpath, but smth wrong with it
        annotationTexts = authorNode.css("Resource") # FIXME: want to use xpath, but smth wrong with it

		# you don't need this - we allready have entity as person, we need just to reference uri
        #if ( !(dbpResUrl.empty?) or !(annotationTexts.empty?) )
        #then
        #    authorsGraph <<[authorURI, RDF.type, @ecrmVocabulary.E21_Person]
        #end

        if !(dbpResUrl.empty?)
        then
            dbpResUrl = RDF::URI.new(dbpResUrl)
            authorsGraph <<[authorURI, 'http://www.w3.org/2002/07/owl#sameAs', dbpResUrl]
        end
        if !(annotationTexts.empty?)
        then
            aid = authorId # FIXME !!1 Why authorId is invisible for next method?
            newAnnotationObject = RDF::URI.new("#{authorsPrefix}#{aid}/annotation/1")
            authorsGraph << [newAnnotationObject, RDF.type, @rmlodVocabulary.AnnotationObject]
            authorsGraph << [authorURI, @rmlodVocabulary[:hasAnnotation], newAnnotationObject]
            annotationTexts.each { |dbpRes|
                dbpResURI =  RDF::URI.new(dbpRes['URI'])
                authorsGraph << [newAnnotationObject, @rmlodVocabulary[:dbpRes], dbpResURI]
            }
        end
    }

    authorsEnrichmentXMLFile.close

    rmgalleryAuthorsEnrichmentRdfFile = File.open("rm_persons_enrichment.ttl","w")
    rmgalleryAuthorsEnrichmentRdfFile.write(authorsGraph.dump(:ttl, :prefixes => @rdf_prefixes))
    rmgalleryAuthorsEnrichmentRdfFile.close

end

=end

=begin

def worksEnrichmentRdfGenerator

    worksPrefix = "#{@rdf_prefixes["rm-lod"]}object"

    idsArray = []

    workIdRegexp = Regexp.new("^#{worksPrefix}\/[0-9]+$")

    RDF::Reader.open("rmgallery_works.ttl") { |reader|
        reader.each_statement { |statement|
            workIdRegexpMatch = workIdRegexp.match(statement.subject)
            if !(workIdRegexpMatch.nil?)
            then
                id = workIdRegexpMatch.to_s.split("\/").last
                if (idsArray.index(id).nil?)
                then
                    idsArray.push(id)
                end
            end

        }
    }

    worksGraph = RDF::Graph.new(:format => :ttl, :prefixes => @rdf_prefixes)

    worksEnrichmentXMLFile = File.open("rmgallery_works_enrichment.xml","r")
    doc = Nokogiri::XML(worksEnrichmentXMLFile)

    idsArray.each { |workId|
        workURI =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}object/#{workId}")
        workNode = doc.xpath("/rmGalleryWorksEnrichment/work[@id='#{workId}']")

        dbpResUrl = ""
        #dbpResUrl = workNode.css("dbpURI").text # FIXME: want to use xpath, but smth wrong with it
        annotationTexts = workNode.css("Resource") # FIXME: want to use xpath, but smth wrong with it

        if ( !(dbpResUrl.empty?) or !(annotationTexts.empty?) )
        then
            worksGraph <<[workURI, RDF.type, @ecrmVocabulary["E22_Man-Made_Object"]]
        end

        if !(dbpResUrl.empty?)
        then
            dbpResUrl = RDF::URI.new(dbpResUrl)
            worksGraph <<[workURI, RDF.type, dbpResUrl]
        end
        if !(annotationTexts.empty?)
        then
            aid = workId # FIXME !!1 Why workId is invisible for next method?
            newAnnotationObject = RDF::URI.new("#{@rdf_prefixes['rm-lod']}objects/#{aid}/annotations/#{SecureRandom.urlsafe_base64(5)}")
            worksGraph << [newAnnotationObject, RDF.type, @rmlodVocabulary.AnnotationObject]
            worksGraph << [workURI, @rmlodVocabulary[:hasAnnotation], newAnnotationObject]
            annotationTexts.each { |dbpRes|
                dbpResURI =  RDF::URI.new(dbpRes['URI'])
                worksGraph << [newAnnotationObject, @rmlodVocabulary[:dbpRes], dbpResURI]
            }
        end
    }

    worksEnrichmentXMLFile.close

    rmgalleryWorksEnrichmentRdfFile = File.new("rmgallery_works_enrichment.ttl","w")
    rmgalleryWorksEnrichmentRdfFile.write(worksGraph.dump(:ttl, :prefixes => @rdf_prefixes))
    rmgalleryWorksEnrichmentRdfFile.close

end

=end

# authorsEnrichmentRdfGenerator
# worksEnrichmentRdfGenerator

