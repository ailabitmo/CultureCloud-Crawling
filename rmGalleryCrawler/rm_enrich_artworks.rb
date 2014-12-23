# encoding: utf-8

require 'json'
require './rm_enrich_common.rb'

BilingualLabel = Struct.new(:en, :ru)
@localeLabels = BilingualLabel.new("en","ru")

@artworks_ttl = RDF::Graph.load('rm_artwork_objects.ttl')
@artworks_notes_ttl = RDF::Graph.load('rm_artwork_notes.ttl')
artworks = Set.new

artworksLabels = Hash.new
artworksNotes = Hash.new

#TODO: use get_artworks_ids() instead of this
RDF::Query::Pattern.new(:s, RDF.type,@ecrmVocabulary['E22_Man-Made_Object']).execute(@artworks_ttl).each { |e22artwork_statement|
    workURI = e22artwork_statement.subject
    artworkNote = Hash.new
    RDF::Query::Pattern.new(workURI, @ecrmVocabulary[:P3_has_note],:o).execute(@artworks_notes_ttl).each { |note_statement|
        artworkNote[note_statement.object.language]=note_statement.object.to_s
    }
    artworksNotes[workURI]=artworkNote
    artworks << workURI
}

artworks_notes_ttl_path = "rm_artworks_annotations.ttl"
if (File.exists?(artworks_notes_ttl_path))
then
    artworks_notes_ttl = RDF::Graph.load(artworks_notes_ttl_path)
else
    artworks_notes_ttl = RDF::Graph.new(:format => :ttl)
end

i = 1
artworks.to_a.each { |workURI|
    puts i
    i+=1
    if (RDF::Query::Pattern.new(workURI, @ecrmVocabulary[:P3_has_note], :o).execute(artworks_notes_ttl).empty?)
    then
        artworksNotes[workURI].each { |locale,note|
            if (note!="")
            then
                annotation=dbpepiaSpotlightAnnotator(note,locale)
                annotation=Nokogiri::HTML(annotation).xpath("//html/body/div").first.inner_html.gsub(/http:\/\/(ru.|)dbpedia.org\/resource\//,URI.unescape("/resource/?uri="+'\0'))
                artworks_notes_ttl << [workURI, @ecrmVocabulary[:P3_has_note], RDF::Literal.new(annotation.force_encoding('utf-8'), :language => locale)] unless annotation.empty?

                json_annotation=JSON.parse(dbpepiaSpotlightAnnotator(note,locale,'application/json'))
                if !(json_annotation.empty?)
                then
                    annotation_uri = RDF::URI.new("#{workURI}/annotation/#{getRandomString}")
                    artworks_notes_ttl << [workURI, @rmlodVocabulary[:has_annotation], annotation_uri]
                    artworks_notes_ttl << [annotation_uri, RDF.type, @rmlodVocabulary[:AnnotationObject]]
                    artworks_notes_ttl << [annotation_uri, DC.language, locale]
=begin

                    artworks_notes_ttl << [workURI, @rmlodVocabulary[:has_annotation], annotation_uri]

                    artworks_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_text], RDF::Literal.new(json_annotation["@text"])]
                    artworks_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_confidence], RDF::Literal.new(json_annotation["@confidence"])]
                    artworks_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_support], RDF::Literal.new(json_annotation["@support"])]
                    artworks_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_types], RDF::Literal.new(json_annotation["@types"])]
                    artworks_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_sparql], RDF::Literal.new(json_annotation["@sparql"])]
                    artworks_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_policy], RDF::Literal.new(json_annotation["@policy"])]
=end
                    json_annotation["Resources"].each { |json_res|
                        res_uri = RDF::URI.new(json_res["@URI"])
                        artworks_notes_ttl << [annotation_uri, @rmlodVocabulary[:dbpRes], res_uri]
=begin
                        res_uri = RDF::URI.new("#{annotation_uri}/dbp-res/#{json_res["@URI"].split('/').last}")
                        artworks_notes_ttl << [annotation_uri, @rmlodVocabulary[:includes_resource], res_uri]
                        artworks_notes_ttl << [res_uri, @rmlodVocabulary[:res_URI], RDF::URI.new(json_res["@URI"])]
                        artworks_notes_ttl << [res_uri, @rmlodVocabulary[:res_support], RDF::Literal.new(json_res["@support"])]
                        artworks_notes_ttl << [res_uri, @rmlodVocabulary[:res_types], RDF::Literal.new(json_res["@types"])]
                        artworks_notes_ttl << [res_uri, @rmlodVocabulary[:res_surfaceForm], RDF::Literal.new(json_res["@surfaceForm"])]
                        artworks_notes_ttl << [res_uri, @rmlodVocabulary[:res_offet], RDF::Literal.new(json_res["@offset"])]
                        artworks_notes_ttl << [res_uri, @rmlodVocabulary[:res_similarityScore], RDF::Literal.new(json_res["@similarityScore"])]
                        artworks_notes_ttl << [res_uri, @rmlodVocabulary[:res_percentageOfSecondRank], RDF::Literal.new(json_res["@percentageOfSecondRank"])]
=end
                    } unless json_annotation["Resources"].nil?
                end
            end
        }
    end
}

puts '== saving data =='
file = File.new(artworks_notes_ttl_path, 'w')
file.write(artworks_notes_ttl.dump(:ttl, :prefixes => @rdf_prefixes))
file.close
