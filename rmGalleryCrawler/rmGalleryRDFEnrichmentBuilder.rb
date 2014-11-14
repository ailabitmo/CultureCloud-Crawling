# encoding: utf-8

# rmgallery dbpedia connections RDF generator
# based on RDF data provided by rmGalleryRDFBuilder.rb
# and data from dbpedia provided by rmGalleryEnrichment.rb
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
include RDF # Additional built-in vocabularies: http://rdf.greggkellogg.net/yard/RDF/Vocabulary.html
require 'securerandom'

@rdf_prefixes = {
    'ecrm' =>  "http://erlangen-crm.org/current/",
    :rdf => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :dbp =>  "http://dbpedia.org/resource/",
    :owl => OWL.to_uri,
    "rm-lod" => "http://rm-lod.org/"
}

authorsPrefix = "#{@rdf_prefixes["rm-lod"]}authors"

idsArray = []

authorIdRegexp = Regexp.new("^#{authorsPrefix}\/[0-9]+$")

RDF::Reader.open("rmgallery_authors.ttl") { |reader|
    reader.each_statement { |statement|
        authorIdRegexpMatch = authorIdRegexp.match(statement.subject)
        if !(authorIdRegexpMatch.nil?)
        then
            id = authorIdRegexpMatch.to_s.split("\/").last
            if (idsArray.index(id).nil?)
            then
                idsArray.push(id)
            end
        end

    }
}

authorsGraph = RDF::Graph.new(:format => :ttl, :prefixes => @rdf_prefixes)

authorsEnrichmentXMLFile = File.open("rmgallery_authors_enrichment.xml","r")
doc = Nokogiri::XML(authorsEnrichmentXMLFile)

idsArray.each { |authorId|
    authorURI =  RDF::URI.new("#{@rdf_prefixes['rm-lod']}authors/#{authorId}")
    authorNode = doc.xpath("/rmGalleryAuthorsEnrichment/author[@id='#{authorId}']")
    dbpResURI = authorNode.css("dbpURI").text
    if !(dbpResURI.empty?)
    then
        authorsGraph << [authorURI, OWL.sameAs, dbpResURI]
    end
}

authorsEnrichmentXMLFile.close

rmgalleryAuthorsEnrichmentRdfFile = File.open("rmgallery_authors_enrichment.ttl","w")
rmgalleryAuthorsEnrichmentRdfFile.write(authorsGraph.dump(:ttl, :prefixes => @rdf_prefixes))
rmgalleryAuthorsEnrichmentRdfFile.close
