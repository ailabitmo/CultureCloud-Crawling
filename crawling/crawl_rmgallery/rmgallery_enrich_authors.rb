# encoding: utf-8

require 'json'
require '../rm_enrich_common.rb'

BilingualLabel = Struct.new(:en, :ru)
@locale_labels = BilingualLabel.new("en","ru")

@persons_ttl = RDF::Graph.load('../results/rmgallery_persons.ttl')
@persons_notes_ttl = RDF::Graph.load('../results/rmgallery_persons_notes.ttl')

puts "Working with persons. Enter action number"
puts "1. Generate dbp-same-as"
puts "2. Generate spotlight annotations"
answr = gets
@action_number=answr.to_i

persons = Set.new

persons_labels = Hash.new
persons_notes = Hash.new

RDF::Query::Pattern.new(:s, RDF.type,@ecrm_vocabulary[:E21_Person]).execute(@persons_ttl).each { |e21person_statement|
    person_uri = e21person_statement.subject
    person_label = Hash.new
    RDF::Query::Pattern.new(person_uri, RDFS.label,:o).execute(@persons_ttl).each { |label_statement|
        person_label[label_statement.object.language]=label_statement.object.to_s
    }
    person_note = Hash.new
    RDF::Query::Pattern.new(person_uri, @ecrm_vocabulary[:P3_has_note],:o).execute(@persons_notes_ttl).each { |note_statement|
        person_note[note_statement.object.language]=note_statement.object.to_s
    }
    persons_labels[person_uri]=person_label
    persons_notes[person_uri]=person_note
    persons << person_uri
}

persons_sameas_ttl_path = "../results/rmgallery_persons_sameas.ttl"
if File.exists?(persons_sameas_ttl_path)
  persons_sameas_ttl = RDF::Graph.load(persons_sameas_ttl_path)
else
    persons_sameas_ttl = RDF::Graph.new(:format => :ttl)
end
persons_notes_ttl_path = "../results/rmgallery_persons_annotations.ttl"
File.exists?(persons_notes_ttl_path) ?
    persons_notes_ttl = RDF::Graph.load(persons_notes_ttl_path) :
    persons_notes_ttl = RDF::Graph.new(:format => :ttl)

i = 1
persons.to_a.each { |personURI|
    puts i
    i+=1
    if @action_number==1
    then
        if RDF::Query::Pattern.new(personURI, OWL.sameAs, :o).execute(persons_sameas_ttl).empty?
        then
            new_dbp_uri = get_dbpedia_url(persons_labels[personURI][:ru],"ru")
            if new_dbp_uri.nil?
            then
                new_dbp_uri = get_dbpedia_url(persons_labels[personURI][:en],"en")
            end
            !(new_dbp_uri.nil?) ? persons_sameas_ttl << [personURI, OWL.sameAs, new_dbp_uri] : puts "found nothing for #{personURI}"
        else
            puts "#{personURI} already linked with dbp"
        end
    elsif @action_number==2
        if RDF::Query::Pattern.new(personURI, @ecrm_vocabulary[:P3_has_note], :o).execute(persons_notes_ttl).empty?
        then
            persons_notes[personURI].each { |locale,note|
                annotation=dbpepia_spotlight_annotator(note,locale)
                annotation=Nokogiri::HTML(annotation).xpath("//html/body/div").first.inner_html.gsub(/http:\/\/(ru.|)dbpedia.org\/resource\//,URI.unescape("/resource/?uri="+'\0'))
                persons_notes_ttl << [personURI, @ecrm_vocabulary[:P3_has_note], RDF::Literal.new(annotation.force_encoding('utf-8'), :language => locale)] unless annotation.empty?

                json_annotation=JSON.parse(dbpepia_spotlight_annotator(note,locale,'application/json'))
                unless json_annotation.empty?
                then
                  annotation_uri = RDF::URI.new("#{personURI}/annotation/#{get_random_string}")
                  persons_notes_ttl << [personURI, @rmlod_vocabulary[:has_annotation], annotation_uri]
                  persons_notes_ttl << [annotation_uri, DC.language, locale]
                  persons_notes_ttl << [annotation_uri, RDF.type, @rmlod_vocabulary[:AnnotationObject]]
=begin

=begin
                    persons_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_text], RDF::Literal.new(json_annotation["@text"])]
                    persons_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_confidence], RDF::Literal.new(json_annotation["@confidence"])]
                    persons_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_support], RDF::Literal.new(json_annotation["@support"])]
                    persons_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_types], RDF::Literal.new(json_annotation["@types"])]
                    persons_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_sparql], RDF::Literal.new(json_annotation["@sparql"])]
                    persons_notes_ttl << [annotation_uri, @rmlod_vocabulary[:annotation_policy], RDF::Literal.new(json_annotation["@policy"])]
=end
                  json_annotation["Resources"].each { |json_res|
                    res_uri = RDF::URI.new(json_res["@URI"])
                    persons_notes_ttl << [annotation_uri, @rmlod_vocabulary[:dbpRes], res_uri]
=begin
                        res_uri = RDF::URI.new("#{annotation_uri}/dbp-res/#{json_res["@URI"].split('/').last}")
                        persons_notes_ttl << [annotation_uri, @rmlod_vocabulary[:includes_resource], res_uri]
                        persons_notes_ttl << [res_uri, @rmlod_vocabulary[:res_URI], RDF::URI.new(json_res["@URI"])]
                        persons_notes_ttl << [res_uri, @rmlod_vocabulary[:res_support], RDF::Literal.new(json_res["@support"])]
                        persons_notes_ttl << [res_uri, @rmlod_vocabulary[:res_types], RDF::Literal.new(json_res["@types"])]
                        persons_notes_ttl << [res_uri, @rmlod_vocabulary[:res_surfaceForm], RDF::Literal.new(json_res["@surfaceForm"])]
                        persons_notes_ttl << [res_uri, @rmlod_vocabulary[:res_offet], RDF::Literal.new(json_res["@offset"])]
                        persons_notes_ttl << [res_uri, @rmlod_vocabulary[:res_similarityScore], RDF::Literal.new(json_res["@similarityScore"])]
                        persons_notes_ttl << [res_uri, @rmlod_vocabulary[:res_percentageOfSecondRank], RDF::Literal.new(json_res["@percentageOfSecondRank"])]
=end
                  } unless json_annotation["Resources"].nil?


                end

            }
        end
    end
}

if @action_number==1
  puts '== saving data =='
    file = File.new(persons_sameas_ttl_path, 'w')
    file.write(persons_sameas_ttl.dump(:ttl, :prefixes => @rdf_prefixes))
    file.close
elsif @action_number==2
    puts '== saving data =='
    file = File.new(persons_notes_ttl_path, 'w')
    file.write(persons_notes_ttl.dump(:ttl, :prefixes => @rdf_prefixes))
    file.close
end
