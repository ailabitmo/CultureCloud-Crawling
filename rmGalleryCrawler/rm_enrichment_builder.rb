# encoding: utf-8

# rmgallery dbpedia connections RDF generator
# based on RDF data provided by rmGalleryRDFBuilder.rb
# and data from dbpedia provided by rmGalleryEnrichment.rb
# Alexey Andreyev: yetanotherandreyev@gmail.com


require 'rubygems'

require 'net/http'
require 'uri'
require 'json'
require 'set'

require 'pathname'
require 'colorize'
require 'io/console'

require 'nokogiri'
require 'rdf/turtle'
include RDF # Additional built-in vocabularies: http://rdf.greggkellogg.net/yard/RDF/Vocabulary.html
require 'securerandom'

@rdf_prefixes = {
    'ecrm' =>  "http://erlangen-crm.org/current/",
    :rdf => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :dbp =>  "http://dbpedia.org/resource/", # Do we really need it? Resources depend from locale
    :owl => OWL.to_uri,
    "rm-lod" => "http://rm-lod.org/",
	"rm-lod-schema" => "http://rm-lod.org/schema/",
}

@ecrmVocabulary = RDF::Vocabulary.new(@rdf_prefixes['ecrm'])
@rmlodVocabulary = RDF::Vocabulary.new(@rdf_prefixes['rm-lod-schema'])

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

authorsEnrichmentRdfGenerator
# worksEnrichmentRdfGenerator
