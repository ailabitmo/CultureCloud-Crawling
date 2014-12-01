# encoding: utf-8

# rmgallery.ru HTML data parser generated
# rmgallery_art.xml to turtle-rdf data parser
# Alexey Andreyev: yetanotherandreyev@gmail.com

require 'io/console'

require 'rubygems'

require 'net/http'
require 'uri'
require 'json'

require 'pathname'
require 'colorize'
require 'io/console'

require 'nokogiri'
require 'rdf/turtle'
include RDF # Additional built-in vocabularies: http://rdf.greggkellogg.net/yard/RDF/Vocabulary.html
require 'securerandom'
require 'digest/md5'


# TODO: cotribute to dbpediafinder: https://github.com/moustaki/dbpediafinder/
# TODO: images rdf
# TODO: genres rdf
# TODO: types rdf

@rdf_prefixes = {
    :ecrm =>  "http://erlangen-crm.org/current/",
    :rdf => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :dbp =>  "http://dbpedia.org/resource/",
    :owl => OWL.to_uri,
    'rm-lod' => "http://rm-lod.org/"
}

@ecrmVocabulary = RDF::Vocabulary.new(@rdf_prefixes[:ecrm])

def authorsRdfGenerator()
	puts "Generating authors"
    # Authors rdf generator:

    @proxy = URI.parse(ENV['HTTP_PROXY']) if ENV['HTTP_PROXY']

    #TODO: ask for this values:
    @dbPediaSpotlightConfidence = 0.2
    @dbPediaSpotlightSupport = 20

    #consoleWidth = IO.console.winsize[1]

    # source file #TODO: specify it
    
    authors = @doc.xpath('//section[@label="author"]/sectionItem')
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
        authorURI =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}authors/#{authorID}") #FIXME: generate real URI
        authorsGraph <<[authorURI, RDF.type, @ecrmVocabulary.E21_Person]              
                      
        authorFullName = authors[i].attributes["label"].text.strip
        authorFullNameLiteral = RDF::Literal.new(authorFullName, :language => currentLocale)
        
        authorsGraph << [authorURI,RDFS.label,authorFullNameLiteral]

        new_E82_ActorAppellation =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}authors/#{authorID}/appelation/#{SecureRandom.urlsafe_base64(5)}")          
                      
        authorsGraph << [new_E82_ActorAppellation,RDFS.label,authorFullNameLiteral]
        authorsGraph << [new_E82_ActorAppellation,RDF.type,@ecrmVocabulary.E82_Actor_Appellation]
                      
        annotationText = authors[i].css("bio")[0].text # FIXME
        annotationTextLiteral = RDF::Literal.new(annotationText, :language => currentLocale)             
        #new_E62_String =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}objects/#{SecureRandom.urlsafe_base64(5)}") #TODO: create separated function
        #authorsGraph << [new_E62_String, RDF.type, @ecrmVocabulary.E62_String]
        #authorsGraph << [new_E62_String, RDFS.label, annotationTextLiteral]              
        #authorsGraph << [new_E82_ActorAppellation, @ecrmVocabulary[:P3_has_note], new_E62_String]
        authorsGraph << [new_E82_ActorAppellation, @ecrmVocabulary[:P3_has_note], annotationTextLiteral]              
                      
        

        authorsGraph << [authorURI, @ecrmVocabulary[:P1_is_identified_by], new_E82_ActorAppellation]
        
		

        #percentage = "authors processed: #{i+1} of #{authorsSize} "
        #puts percentage+"#"*(consoleWidth-percentage.length)
    }
    puts "generating file..."

    #RDF::Writer.open(rmgallery_authors_filepath, :prefixes => @rdf_prefixes) do |writer|
    #    authorsGraph.each_statement do |statement|
    #        writer << statement
    #    end
    #end

    #puts @rdf_prefixes
    authorsFile = File.new(rmgallery_authors_filepath,"w")
    authorsFile.write(authorsGraph.dump(:ttl, :prefixes => @rdf_prefixes))
    authorsFile.close
    
    
  
end

def artRdfGenerator()
    puts "Generating objects"
    # Works rdf generator:

    @proxy = URI.parse(ENV['HTTP_PROXY']) if ENV['HTTP_PROXY']

    #TODO: ask for this values:
    @dbPediaSpotlightConfidence = 0.2
    @dbPediaSpotlightSupport = 20

    #consoleWidth = IO.console.winsize[1]


    works = @doc.xpath('//artItem')
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
    worksSize.times { |i|
        currentLocale = works[i].parent.parent.parent["locale"] # FIXME: shame on me
        workID = works[i].attributes["id"].text
        workURI =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}objects/#{workID}") #FIXME: generate real URI
        #authorFullName = works[i].attributes["authorName"].text
        #authorFullNameLiteral = RDF::Literal.new(authorFullName, :language => currentLocale)
        worksGraph << [workURI, RDF.type, @ecrmVocabulary["E22_Man-Made_Object"]]

        new_E12_Production =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}objects/#{workID}/production/#{SecureRandom.urlsafe_base64(5)}") 
        worksGraph << [new_E12_Production, RDF.type, @ecrmVocabulary.E12_Production]            
        worksGraph << [workURI, @ecrmVocabulary[:P108i_was_produced_by], new_E12_Production]              
        
  
        workTitle = works[i].attributes["label"].text.strip
        workTitleLiteral = RDF::Literal.new(workTitle, :language => currentLocale)
        if (RDF::Query::Pattern.new(:s, RDFS.label, workTitleLiteral).execute(worksGraph).size>0)
        then
            puts "warning: work title #{workTitle} already exists..."            
        end
        new_E35_Title =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}objects/#{workID}/title/#{SecureRandom.urlsafe_base64(5)}")
        worksGraph << [new_E35_Title, RDF.type, @ecrmVocabulary.E35_Title]
        worksGraph << [new_E35_Title, RDFS.label, workTitleLiteral]           
        worksGraph << [workURI, @ecrmVocabulary[:P102_has_title], new_E35_Title]
                    
                    
        annotationText = works[i].css("annotation")[0].text.strip # FIXME
        annotationTextLiteral = RDF::Literal.new(annotationText, :language => currentLocale)             
        #new_E62_String =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}objects/#{SecureRandom.urlsafe_base64(5)}")
        #worksGraph << [new_E62_String, RDF.type, @ecrmVocabulary.E62_String]
        #worksGraph << [new_E62_String, RDFS.label, annotationTextLiteral]
        #worksGraph << [workURI, @ecrmVocabulary[:P3_has_note], new_E62_String]
        worksGraph << [workURI, @ecrmVocabulary[:P3_has_note], annotationTextLiteral]      
                    
        workDescription = works[i].css("description").text
        workDescriptions = workDescription.split(".")
        workDescriptions.each { |wd|
            if ( !(wd.index(" х ").nil?) or !(wd.index(" x ").nil?) )
            then
                new_E54_Dimension =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}objects/#{workID}/dimensions/#{SecureRandom.urlsafe_base64(5)}")
                dimensionsLiteralEn = RDF::Literal.new("dimensions", :language => "en")
                dimensionsLiteralRu = RDF::Literal.new("размеры", :language => "ru")              
                worksGraph << [new_E54_Dimension,RDFS.label,dimensionsLiteralEn]
                worksGraph << [new_E54_Dimension,RDFS.label,dimensionsLiteralRu]
                new_E60_Number =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}objects/#{workID}/numbers/#{SecureRandom.urlsafe_base64(5)}")
                worksGraph << [new_E60_Number,RDFS.label,wd]
                worksGraph << [new_E54_Dimension, @ecrmVocabulary[:P90_has_value], new_E60_Number]              
                worksGraph << [workURI, @ecrmVocabulary[:P43_has_dimension] ,new_E54_Dimension]
                workDescriptions.delete(wd)
            end
        }         
        new_E55_Type =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}objects/thetypes/#{SecureRandom.urlsafe_base64(5)}") #TODO: unify
        worksGraph << [new_E55_Type, RDF.type, @ecrmVocabulary.E55_Type]
        workDescriptionsLiteral =  workDescriptions.join(". ")
        worksGraph << [new_E55_Type, RDFS.label, workDescriptionsLiteral]            
        worksGraph << [workURI, @ecrmVocabulary[:P32_used_general_technique], new_E55_Type]
        groupLabel = works[i].parent.parent["label"] # FIXME: shame on me
        case groupLabel
        when "author"
            authorID = works[i].parent["id"]
            authorURI =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}authors/#{authorID}") # TODO: separate to function       
            new_part_E12_Production = RDF::URI.new("#{@rdf_prefixes['rm-lod']}objects/#{workID}/production/#{SecureRandom.urlsafe_base64(5)}") 
			worksGraph << [new_part_E12_Production, RDF.type, @ecrmVocabulary.E12_Production]            
			worksGraph << [new_E12_Production, @ecrmVocabulary[:P9_consists_of], new_part_E12_Production]            
			worksGraph << [new_part_E12_Production, @ecrmVocabulary[:P14_carried_out_by], authorURI]    
        when "genge"
            genreID= works[i].parent["id"]
            genreID=  RDF::URI.new("#{@rdf_prefixes['rm-lod']}object/genres/#{genreID}")             
            worksGraph << [workURI, RDF::URI("FIXME:genreID") ,genreID] #FIXME: wrong usage cdcrm
        when "type"
            typeID= works[i].parent["id"]
            typeIDURI = RDF::URI.new("#{@rdf_prefixes['rm-lod']}object/types/#{typeID}")        
            worksGraph << [workURI, RDF::URI("FIXME:typeID") ,typeIDURI] #FIXME: wrong usage cdcrm
        end
        
        jpgURI = RDF::URI.new("http://rmgallery.ru/files/medium/#{workID}_98.jpg") #TODO: save all data to our server 
        worksGraph << [workURI, @ecrmVocabulary[:P138i_has_representation] ,jpgURI] 

        #percentage = "art processed: #{i+1} of #{worksSize} "
        #puts percentage+"#"*(consoleWidth-percentage.length)


    }
    #puts "press return to continue"
    # puts "graph generated in memory. to save to file press return (WARNING: takes a lot of time and RAM (more that 3GB)"
    #gets
    puts "generating file..."

    #RDF::Writer.open(rmgallery_works_filepath, :format => :ttl) do |writer|
    #    writer.prefix 'ecrm', RDF::URI("http://erlangen-crm.org/current/")
    #    writer.prefix :rdf , RDF.to_uri
    #    writer.prefix :rdfs , RDFS.to_uri
    #    writer.prefix :dbp ,  RDF::URI("http://dbpedia.org/resource/") # Do we really need it? Resources depend from locale
    #    writer.prefix :owl , OWL.to_uri
    #    writer.prefix "rm-lod", RDF::URI("http://rm-lod.org/")
    #    puts writer.prefixes
    #    worksGraph.each do |statement|
    #        writer << statement
    #    end
    #end
	
    #puts @rdf_prefixes
    worksFile = File.new("rmgallery_works.ttl","w")
    worksFile.write(worksGraph.dump(:ttl, :prefixes => @rdf_prefixes))
    worksFile.close

end

def genresTypesRdfGenerator()
	puts "Generating types"
    graph = RDF::Graph.new(:format => :ttl, :prefixes => @rdf_prefixes)

    # source file #TODO: specify it
    
    ["genre","type"].each { |label|
        tags = @doc.xpath("//section[@label='#{label}']/sectionItem")
        tags.size.times { |i|
            currentLocale = tags[i].parent.parent["locale"] # FIXME: shame on me
            labelURI = RDF::URI.new("#{@rdf_prefixes['rm-lod']}object/#{label}s/#{tags[i].attributes["id"].text}")
            labelTitle = tags[i].attributes["label"].text
            labelTitlelLiteral = RDF::Literal.new(labelTitle, :language => currentLocale)
            graph << [labelURI, RDFS.label, labelTitlelLiteral]
            graph << [labelURI, RDF::URI("FIXME:tagType"), label] #FIXME:
        }
    }
    puts "generating file..."
    rmgallery_genrestypes_filepath = "rmgallery_genrestypes.ttl"

    #RDF::Writer.open(rmgallery_genrestypes_filepath, :prefixes => @rdf_prefixes) do |writer|
    #    graph.each_statement do |statement|
    #        writer << statement
    #    end
    #end
	
    tagsFile = File.new(rmgallery_genrestypes_filepath,"w")
    tagsFile.write(graph.dump(:ttl, :prefixes => @rdf_prefixes))
    tagsFile.close
end

puts "please, uncomment functions calls you need in sources"
artFile = File.open("rmgallery_art.xml","r")
@doc = Nokogiri::XML(artFile)
#authorsRdfGenerator()
artRdfGenerator()
#genresTypesRdfGenerator()
artFile.close
puts "done. exiting."
