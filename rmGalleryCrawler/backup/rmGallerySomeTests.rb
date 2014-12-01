# encoding: utf-8

# rmgallery crawling/enrichment result testing
# Alexey Andreyev: yetanotherandreyev@gmail.com

require 'set'

require 'rubygems'

require 'pathname'
require 'io/console'

require 'nokogiri'
require 'rdf/turtle'

rmgallery_art_xml_filepath = "rmgallery_art.xml"

@ecrmPrefix = "http://erlangen-crm.org/current/"
@ecrmVocabulary = RDF::Vocabulary.new(@ecrmPrefix)

rmgallery_authors_ttl_filepath = "rmgallery_authors.ttl"
rmgallery_works_ttl_filepath = "rmgallery_works.ttl"
rmgallery_genrestypes_ttl_filepath = "rmgallery_genrestypes.ttl"

rmgallery_authors_enrichment_xml_filepath = "rmgallery_authors_enrichment.xml"
rmgallery_works_enrichment_xml_filepath = "rmgallery_works_enrichment.xml"

rmgallery_authors_enrichment_ttl_filepath = "rmgallery_authors_enrichment.ttl"
rmgallery_works_enrichment_ttl_filepath = "rmgallery_works_enrichment.ttl"

rmgallery_art_xml_file = File.open(rmgallery_art_xml_filepath,"r")
rmgallery_art_xml = Nokogiri::XML(rmgallery_art_xml_file)

# authors:
authorsFromArtXML = rmgallery_art_xml.xpath('//section[@label="author"]/sectionItem')
authorsIdsArrayFromArtXML = Set.new
puts "Authors items number in rmgallery art xml: #{authorsFromArtXML.size}"
authorsFromArtXML.size.times { |i|
    id = authorsFromArtXML[i].attributes["id"].text
    authorsIdsArrayFromArtXML << id
}
puts "Authors items number with no duplicates in rmgallery art xml: #{authorsIdsArrayFromArtXML.size}"

puts "Authors items number in rmgallery authors ttl: #{RDF::Query::Pattern.new(:s, RDF.type, @ecrmVocabulary.E21_Person).execute(RDF::Repository.load(rmgallery_authors_ttl_filepath)).size}"

# art:
worksFromArtXML = rmgallery_art_xml.xpath('//artItem')
worksIdsArrayFromArtXML = Set.new
puts "Work items number in rmgallery art xml: #{worksFromArtXML.size}"
worksFromArtXML.size.times { |i|
    id = worksFromArtXML[i].attributes["id"].text
    worksIdsArrayFromArtXML << id
}
puts "Work items number with no duplicates in rmgallery art xml: #{worksIdsArrayFromArtXML.size}"

puts "Work items number in rmgallery works ttl: #{RDF::Query::Pattern.new(:s, RDF.type, @ecrmVocabulary['E22_Man-Made_Object']).execute(RDF::Repository.load(rmgallery_works_ttl_filepath)).size}"