# encoding: utf-8

require 'json'
require '../rm_enrich_common.rb'

BilingualLabel = Struct.new(:en, :ru)
@locale_labels = BilingualLabel.new("en","ru")

@artworks_ttl = RDF::Graph.load('../results/rmgallery_artwork_objects.ttl')
@artworks_notes_ttl = RDF::Graph.load('../results/rmgallery_artwork_notes.ttl')
artworks = Set.new

# FIXME: artworksLabels = Hash.new
artworks_notes = Hash.new

#TODO: use get_artworks_ids() instead of this
RDF::Query::Pattern.new(:s, RDF.type,@ecrm_vocabulary['E22_Man-Made_Object']).execute(@artworks_ttl).each { |e22artwork_statement|
    work_uri = e22artwork_statement.subject
    artwork_note = Hash.new
    RDF::Query::Pattern.new(work_uri, @ecrm_vocabulary[:P3_has_note],:o).execute(@artworks_notes_ttl).each { |note_statement|
        artwork_note[note_statement.object.language]=note_statement.object.to_s
    }
    artworks_notes[work_uri]=artwork_note
    artworks << work_uri
}

artworks_notes_ttl_path = "../results/rmgallery_artworks_annotations.ttl"
File.exists?(artworks_notes_ttl_path) ?
    artworks_notes_ttl = RDF::Graph.load(artworks_notes_ttl_path) :
    artworks_notes_ttl = RDF::Graph.new(:format => :ttl)

i = 1
artworks.to_a.each { |workURI|
    puts i
    i+=1
    if RDF::Query::Pattern.new(workURI, @ecrm_vocabulary[:P3_has_note], :o).execute(artworks_notes_ttl).empty?
    then
        artworks_notes[workURI].each { |locale,note|
            if note!=''
            then
                annotation=dbpepia_spotlight_annotator(note,locale)
                annotation=Nokogiri::HTML(annotation).xpath("//html/body/div").first.inner_html.gsub(/http:\/\/(ru.|)dbpedia.org\/resource\//,URI.unescape("/resource/?uri="+'\0'))
                artworks_notes_ttl << [workURI, @ecrm_vocabulary[:P3_has_note], RDF::Literal.new(annotation.force_encoding('utf-8'), :language => locale)] unless annotation.empty?

                json_annotation=JSON.parse(dbpepia_spotlight_annotator(note,locale,'application/json'))
                unless json_annotation.empty?
                then
                  annotation_uri = RDF::URI.new("#{workURI}/annotation/#{get_random_string}")
                  artworks_notes_ttl << [workURI, @rmlod_vocabulary[:has_annotation], annotation_uri]
                  artworks_notes_ttl << [annotation_uri, RDF.type, @rmlod_vocabulary[:AnnotationObject]]
                  artworks_notes_ttl << [annotation_uri, DC.language, locale]
=begin

                    artworks_notes_ttl << [work_uri, @rmlod_vocabulary[:has_annotation], annotation_uri]

                    artworks_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_text], RDF::Literal.new(json_annotation["@text"])]
                    artworks_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_confidence], RDF::Literal.new(json_annotation["@confidence"])]
                    artworks_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_support], RDF::Literal.new(json_annotation["@support"])]
                    artworks_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_types], RDF::Literal.new(json_annotation["@types"])]
                    artworks_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_sparql], RDF::Literal.new(json_annotation["@sparql"])]
                    artworks_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_policy], RDF::Literal.new(json_annotation["@policy"])]
=end
                  json_annotation["Resources"].each { |json_res|
                    res_uri = RDF::URI.new(json_res["@URI"])
                    artworks_notes_ttl << [annotation_uri, @rmlod_vocabulary[:dbpRes], res_uri]
=begin
                        res_uri = RDF::URI.new("#{annotation_uri}/dbp-res/#{json_res["@URI"].split('/').last}")
                        artworks_notes_ttl << [annotation_uri, @rmlod_vocabulary[:includes_resource], res_uri]
                        artworks_notes_ttl << [res_uri, @rmlod_vocabulary[:res_URI], RDF::URI.new(json_res["@URI"])]
                        artworks_notes_ttl << [res_uri, @rmlod_vocabulary[:res_support], RDF::Literal.new(json_res["@support"])]
                        artworks_notes_ttl << [res_uri, @rmlod_vocabulary[:res_types], RDF::Literal.new(json_res["@types"])]
                        artworks_notes_ttl << [res_uri, @rmlod_vocabulary[:res_surfaceForm], RDF::Literal.new(json_res["@surfaceForm"])]
                        artworks_notes_ttl << [res_uri, @rmlod_vocabulary[:res_offset], RDF::Literal.new(json_res["@offset"])]
                        artworks_notes_ttl << [res_uri, @rmlod_vocabulary[:res_similarityScore], RDF::Literal.new(json_res["@similarityScore"])]
                        artworks_notes_ttl << [res_uri, @rmlod_vocabulary[:res_percentageOfSecondRank], RDF::Literal.new(json_res["@percentageOfSecondRank"])]
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
