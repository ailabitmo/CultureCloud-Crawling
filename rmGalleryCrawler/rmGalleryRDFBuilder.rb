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
#FIXME: correct rdf prefixes if using include RDF
include RDF # Additional built-in vocabularies: http://rdf.greggkellogg.net/yard/RDF/Vocabulary.html
require 'securerandom'


# TODO: cotribute to dbpediafinder: https://github.com/moustaki/dbpediafinder/
# TODO: images rdf
# TODO: genres rdf
# TODO: types rdf

@rdf_prefixes = {
    'ecrm' =>  "http://erlangen-crm.org/ontology/ecrm/ecrm_current.owl#",
    :rdf => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :dbp =>  "http://dbpedia.org/resource/",
    :owl => OWL.to_uri,
    "ourprefix" => "http://oursite.org/resource/"
}

@ecrmVocabulary = RDF::Vocabulary.new(@rdf_prefixes['ecrm'])

def authorsRdfGenerator()
    # Authors rdf generator:

    @proxy = URI.parse(ENV['HTTP_PROXY']) if ENV['HTTP_PROXY']

    #TODO: ask for this values:
    @dbPediaSpotlightConfidence = 0.2
    @dbPediaSpotlightSupport = 20

    consoleWidth = IO.console.winsize[1]

    # source file #TODO: specify it
    artFile = File.open("rmgallery_art.xml","r")
    doc = Nokogiri::XML(artFile)

    authors = doc.xpath('//section[@label="author"]/sectionItem')
    authorsSize = authors.size
    puts "Found #{authors.size} authors"

    
    

    # authors file # TODO: specify it
    rmgallery_authors_filepath = "rmgallery_authors.ttl"
    
=begin
    if !(File.file?(rmgallery_authors_filepath)) then
        puts "#{rmgallery_authors_filepath} was not found in working dir"
    else
        puts "#{rmgallery_authors_filepath} was found in working dir"
        authorsFile = File.open(rmgallery_authors_filepath,"r")
        previousAuthorsGraph = RDF::Graph.load(authorsFile) # FIXME: check is data ok
        authorsFile.close
    end
=end

    authorsGraph = RDF::Graph.new(:format => :ttl, :prefixes => @rdf_prefixes)

=begin    
    if !(previousAuthorsGraph.nil?) then
        authorsGraph = previousAuthorsGraph
    end
=end    

    authorsSize.times { |i|
        currentLocale = authors[i].parent.parent["locale"] # FIXME: shame on me
        authorID = authors[i].attributes["id"].text
        authorURI =  RDF::URI.new("#{@rdf_prefixes['ourprefix']}authors/#{authorID}") #FIXME: generate real URI
        authorsGraph <<[authorURI, RDF.type, @ecrmVocabulary.E21_Person]              
                      
        authorFullName = authors[i].attributes["label"].text
        authorFullNameLiteral = RDF::Literal.new(authorFullName, :language => currentLocale)
        
        new_E82_ActorAppellation =  RDF::URI.new("#{@rdf_prefixes['ourprefix']}objects/#{SecureRandom.urlsafe_base64(5)}")          
                      
        authorsGraph << [new_E82_ActorAppellation,RDFS.label,authorFullNameLiteral]
        authorsGraph << [new_E82_ActorAppellation,RDF.type,@ecrmVocabulary.E82_Actor_Appellation]
                      
        annotationText = authors[i].css("bio")[0].text # FIXME
        annotationTextLiteral = RDF::Literal.new(annotationText, :language => currentLocale)             
        new_E62_String =  RDF::URI.new("#{@rdf_prefixes['ourprefix']}objects/#{SecureRandom.urlsafe_base64(5)}") #TODO: create separated function
        authorsGraph << [new_E62_String, RDF.type, @ecrmVocabulary.E62_String]
        authorsGraph << [new_E62_String, RDFS.label, annotationTextLiteral]              
        authorsGraph << [new_E82_ActorAppellation, @ecrmVocabulary[:P3_has_note], new_E62_String]              
                      
        

        authorsGraph << [authorURI, @ecrmVocabulary[:P1_is_identified_by], new_E82_ActorAppellation]
        


        percentage = "authors processed: #{i+1} of #{authorsSize} "
        puts percentage+"#"*(consoleWidth-percentage.length)
    }
    puts "generating file..."

    authorsFile = File.new(rmgallery_authors_filepath,"w")
    authorsFile.write(authorsGraph.dump(:ttl, :prefixes => @rdf_prefixes))
    authorsFile.close
    
    artFile.close
  
end

def artRdfGenerator()
    # Works rdf generator:

    @proxy = URI.parse(ENV['HTTP_PROXY']) if ENV['HTTP_PROXY']

    #TODO: ask for this values:
    @dbPediaSpotlightConfidence = 0.2
    @dbPediaSpotlightSupport = 20

    consoleWidth = IO.console.winsize[1]

    # source file #TODO: specify it
    artFile = File.open("rmgallery_art.xml","r")
    doc = Nokogiri::XML(artFile)

    works = doc.xpath('//artItem')
    worksSize = works.size
    puts "Found #{worksSize} works"


    # authors file # TODO: specify it
    rmgallery_works_filepath = "rmgallery_works.ttl"
=begin    
    if !(File.file?(rmgallery_works_filepath)) then
        puts "#{rmgallery_works_filepath} was not found in working dir"
    else
        puts "#{rmgallery_works_filepath} was found in working dir"
        worksFile = File.open(rmgallery_works_filepath,"r")
        previousWorksGraph = RDF::Graph.load(worksFile) # FIXME: check is data ok
        worksFile.close
    end
=end    

    worksGraph = RDF::Graph.new(:format => :ttl, :prefixes => @rdf_prefixes)
=begin
    if !(previousWorksGraph.nil?) then
        worksGraph = previousWorksGraph
    end
=end  
    # worksSize
    400.times { |i|
        currentLocale = works[i].parent.parent.parent["locale"] # FIXME: shame on me
        workID = works[i].attributes["id"].text
        workURI =  RDF::URI.new("#{@rdf_prefixes['ourprefix']}works/#{workID}") #FIXME: generate real URI
        #authorFullName = works[i].attributes["authorName"].text
        #authorFullNameLiteral = RDF::Literal.new(authorFullName, :language => currentLocale)
        worksGraph << [workURI, RDF.type, @ecrmVocabulary.E38_Image]
        new_E65_Creation =  RDF::URI.new("#{@rdf_prefixes['ourprefix']}objects/#{SecureRandom.urlsafe_base64(5)}") #FIXME
        worksGraph << [new_E65_Creation, RDF.type, @ecrmVocabulary.E65_Creation]            
        worksGraph << [new_E65_Creation, @ecrmVocabulary[:P94_has_created], workURI]              
        
        workTitle = works[i].attributes["label"].text
        workTitleLiteral = RDF::Literal.new(workTitle, :language => currentLocale)
        new_E35_Title =  RDF::URI.new("#{@rdf_prefixes['ourprefix']}objects/#{SecureRandom.urlsafe_base64(5)}")
        worksGraph << [new_E35_Title, RDF.type, @ecrmVocabulary.E35_Title]
        worksGraph << [new_E35_Title, RDFS.label, workTitleLiteral]           
        worksGraph << [workURI, @ecrmVocabulary[:P102_has_title], new_E35_Title]
                    
        annotationText = works[i].css("annotation")[0].text # FIXME
        annotationTextLiteral = RDF::Literal.new(annotationText, :language => currentLocale)             
        new_E62_String =  RDF::URI.new("#{@rdf_prefixes['ourprefix']}objects/#{SecureRandom.urlsafe_base64(5)}")
        worksGraph << [new_E62_String, RDF.type, @ecrmVocabulary.E62_String]
        worksGraph << [new_E62_String, RDFS.label, annotationTextLiteral]
        worksGraph << [workURI, @ecrmVocabulary[:P3_has_note], new_E62_String]
                    
        workDescription = works[i].css("description").text
        workDescriptions = workDescription.split(".")
        workDescriptions.each { |wd|
            if ( !(wd.index(" х ").nil?) or !(wd.index(" x ").nil?) )
            then
                new_E54_Dimension =  RDF::URI.new("#{@rdf_prefixes['ourprefix']}objects/#{SecureRandom.urlsafe_base64(5)}")
                dimensionsLiteralEn = RDF::Literal.new("dimensions", :language => "en")
                dimensionsLiteralRu = RDF::Literal.new("размеры", :language => "ru")              
                worksGraph << [new_E54_Dimension,RDFS.label,dimensionsLiteralEn]
                worksGraph << [new_E54_Dimension,RDFS.label,dimensionsLiteralRu]
                new_E60_Number =  RDF::URI.new("#{@rdf_prefixes['ourprefix']}objects/#{SecureRandom.urlsafe_base64(5)}")
                worksGraph << [new_E60_Number,RDFS.label,wd]
                worksGraph << [new_E54_Dimension, @ecrmVocabulary[:P90_has_value], new_E60_Number]              
                worksGraph << [workURI, @ecrmVocabulary[:P43_has_dimension] ,new_E54_Dimension]
                workDescriptions.delete(wd)
            end
        }
        new_E55_Type =  RDF::URI.new("#{@rdf_prefixes['ourprefix']}objects/#{SecureRandom.urlsafe_base64(5)}") #FIXME
        worksGraph << [new_E55_Type, RDF.type, @ecrmVocabulary.E55_Type]
        workDescriptionsLiteral =  workDescriptions.join(". ")
        worksGraph << [new_E55_Type, RDFS.label, workDescriptionsLiteral]            
        worksGraph << [workURI, @ecrmVocabulary[:P32_used_general_technique], new_E55_Type]
        groupLabel = works[i].parent.parent["label"] # FIXME: shame on me
        case groupLabel
        when "author"
            authorID = works[i].parent["id"]
            authorURI =  RDF::URI.new("#{@rdf_prefixes['ourprefix']}authors/#{authorID}") # TODO: separate to function       
            worksGraph << [new_E65_Creation, @ecrmVocabulary[:P14_carried_out_by],authorURI] #FIXME: wrong usage cdcrm
        when "genge"
            genreID= works[i].parent["id"]
            genreID=  RDF::URI.new("#{@rdf_prefixes['ourprefix']}object/#{genreID}")             
            worksGraph << [workURI, "FIXME:genreID" ,genreID] #FIXME: wrong usage cdcrm
        when "type"
            typeID= works[i].parent["id"]
            typeIDURI = RDF::URI.new("#{@rdf_prefixes['ourprefix']}object/#{typeID}")        
            worksGraph << [workURI, "FIXME:typeID" ,typeIDURI] #FIXME: wrong usage cdcrm
        end
        
        jpgURI = RDF::URI.new("http://rmgallery.ru/files/medium/#{workID}_98.jpg") #TODO: save all data to our server 
        worksGraph << [workURI, @ecrmVocabulary[:P138i_has_representation] ,jpgURI] #FIXME: wrong usage cdcrm            

        percentage = "art processed: #{i+1} of #{worksSize} "
        puts percentage+"#"*(consoleWidth-percentage.length)


    }
    puts "press return to continue"
    # puts "graph generated in memory. to save to file press return (WARNING: takes a lot of time and RAM (more that 3GB)"
    gets
    puts "generating file..."

    worksFile = File.new(rmgallery_works_filepath,"w")
    worksFile.write(worksGraph.dump(:ttl, :prefixes => @rdf_prefixes))
    worksFile.close



    artFile.close
end

def genresTypesRdfGenerator()
    graph = RDF::Graph.new(:format => :ttl, :prefixes => @rdf_prefixes)

    # source file #TODO: specify it
    artFile = File.open("rmgallery_art.xml","r")
    doc = Nokogiri::XML(artFile)
    ["genre","type"].each { |label|
        tags = doc.xpath("//section[@label='#{label}']/sectionItem")
        tags.size.times { |i|
            currentLocale = tags[i].parent.parent["locale"] # FIXME: shame on me
            labelURI = RDF::URI.new("#{@rdf_prefixes['ourprefix']}object/#{tags[i].attributes["id"].text}")
            labelTitle = tags[i].attributes["label"].text
            labelTitlelLiteral = RDF::Literal.new(labelTitle, :language => currentLocale)
            graph << [labelURI, RDFS.label, labelTitlelLiteral]
            graph << [labelURI, "FIXME:tagType", label] #FIXME:
        }
    }
    puts "generating file..."
    rmgallery_genrestypes_filepath = "rmgallery_genrestypes.ttl"
    tagsFile = File.new(rmgallery_genrestypes_filepath,"w")
    tagsFile.write(graph.dump(:ttl, :prefixes => @rdf_prefixes))
    tagsFile.close
end

puts "please, uncomment functions calls you need in sources"
authorsRdfGenerator()
artRdfGenerator()
genresTypesRdfGenerator()
puts "done. exiting."
