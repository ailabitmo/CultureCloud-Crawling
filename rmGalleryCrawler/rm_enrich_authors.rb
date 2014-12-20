# encoding: utf-8

require 'json'
require './rm_enrich_common.rb'

BilingualLabel = Struct.new(:en, :ru)
@localeLabels = BilingualLabel.new("en","ru")

@persons_ttl = RDF::Graph.load('rm_persons.ttl')

puts "Working with persons. Enter action number"
puts "1. Generate dbp-same-as"
puts "2. Generate spotlight annotations"
answr = gets
@action_number=answr.to_i

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

i = 1
persons.to_a.each { |personURI|
    puts i
    i+=1
    if (@action_number==1)
    then
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
    elsif (@action_number==2)
        if (RDF::Query::Pattern.new(personURI, @ecrmVocabulary[:P3_has_note], :o).execute(persons_notes_ttl).empty?)
        then
            personsNotes[personURI].each { |locale,note|
                annotation=dbpepiaSpotlightAnnotator(note,locale)
                annotation=Nokogiri::HTML(annotation).xpath("//html/body/div").first.inner_html.gsub(/http:\/\/(ru.|)dbpedia.org\/resource\//,URI.unescape("http://heritage.vismart.biz/resource/?uri="+'\0'))
                persons_notes_ttl << [personURI, @ecrmVocabulary[:P3_has_note], RDF::Literal.new(annotation.force_encoding('utf-8'), :language => locale)] unless annotation.empty?

                json_annotation=JSON.parse(dbpepiaSpotlightAnnotator(note,locale,'application/json'))
                if !(json_annotation.empty?)
                then
                    annotation_uri = RDF::URI.new("#{personURI}/annotation/1")
                    persons_notes_ttl << [personURI, @rmlodVocabulary[:has_annotation], annotation_uri]

                    persons_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_text], RDF::Literal.new(json_annotation["@text"])]
                    persons_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_confidence], RDF::Literal.new(json_annotation["@confidence"])]
                    persons_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_support], RDF::Literal.new(json_annotation["@support"])]
                    persons_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_types], RDF::Literal.new(json_annotation["@types"])]
                    persons_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_sparql], RDF::Literal.new(json_annotation["@sparql"])]
                    persons_notes_ttl << [annotation_uri, @rmlodVocabulary[:annotation_policy], RDF::Literal.new(json_annotation["@policy"])]

                    json_annotation["Resources"].each { |json_res|
                        res_uri = RDF::URI.new("#{annotation_uri}/dbp-res/#{json_res["@URI"].split('/').last}")
                        persons_notes_ttl << [annotation_uri, @rmlodVocabulary[:includes_resource], res_uri]
                        persons_notes_ttl << [res_uri, @rmlodVocabulary[:res_URI], RDF::Literal.new(json_res["@URI"])]
                        persons_notes_ttl << [res_uri, @rmlodVocabulary[:res_support], RDF::Literal.new(json_res["@support"])]
                        persons_notes_ttl << [res_uri, @rmlodVocabulary[:res_types], RDF::Literal.new(json_res["@types"])]
                        persons_notes_ttl << [res_uri, @rmlodVocabulary[:res_surfaceForm], RDF::Literal.new(json_res["@surfaceForm"])]
                        persons_notes_ttl << [res_uri, @rmlodVocabulary[:res_offet], RDF::Literal.new(json_res["@offset"])]
                        persons_notes_ttl << [res_uri, @rmlodVocabulary[:res_similarityScore], RDF::Literal.new(json_res["@similarityScore"])]
                        persons_notes_ttl << [res_uri, @rmlodVocabulary[:res_percentageOfSecondRank], RDF::Literal.new(json_res["@percentageOfSecondRank"])]
                    } unless json_annotation["Resources"].nil?


                end

            }
        end
    end
}

if (@action_number==1)
then
    puts '== saving data =='
    file = File.new(persons_sameas_ttl_path, 'w')
    file.write(persons_sameas_ttl.dump(:ttl, :prefixes => @rdf_prefixes))
    file.close
elsif (@action_number==2)
    puts '== saving data =='
    file = File.new(persons_notes_ttl_path, 'w')
    file.write(persons_notes_ttl.dump(:ttl, :prefixes => @rdf_prefixes))
    file.close
end
