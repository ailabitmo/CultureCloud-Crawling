# encoding: utf-8

require 'set'
require 'rubygems'
require 'io/console'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'rdf/turtle'
include RDF # Additional built-in vocabularies: http://rdf.greggkellogg.net/yard/RDF/Vocabulary.html
require 'rdf/xsd'
require 'securerandom'
require './rm_crawl_common'

BilingualLabel = Struct.new(:en, :ru)
@locale_labels = BilingualLabel.new(:en, :ru)
@annotation_labels = BilingualLabel.new("Annotation", "Аннотация")


def get_image_url(object_id)
  "http://culturecloud.ru/image/#{object_id}"
end

def crawl_title(object_id)
  title = Hash.new
  @locale_labels.each do |loc|
    Nokogiri::HTML(get_cached_artwork_page(object_id, loc)).
        css('div[data-role=content]').each do |content|
      h2 = content.css('h2[align=center]').text
      last_sentence = h2.split('.').last
      h2.slice! last_sentence if last_sentence and last_sentence != h2
      title[loc] = h2.strip.chomp('.') unless h2.empty?
    end
  end
  title
end

def crawl_annotation(object_id)
  annotation = Hash.new
  @locale_labels.each do |locale_label|
    Nokogiri::HTML(get_cached_artwork_page(object_id, locale_label)).
        css('div[data-role=collapsible]').each do |collapsible|
      if collapsible.css('h3').text.strip == @annotation_labels[locale_label]
        a = collapsible.css('p').text.strip
        annotation[locale_label] = a unless a.empty?
      end
    end
  end
  annotation
end

@graph_images = RDF::Graph.new(:format => :ttl)
@graph_artwork = RDF::Graph.new(:format => :ttl)
@graph_notes = RDF::Graph.new(:format => :ttl)
@graph_representation = RDF::Graph.new(:format => :ttl)
@graph_titles = RDF::Graph.new(:format => :ttl)

@artwork_ownerships_ttl = RDF::Graph.load('rm_artwork_ownerships.ttl')
@genres_ttl = RDF::Graph.load('rm_genres.ttl')

get_artwork_ids.each { |artwork_id|
  puts "artworkID: #{artwork_id}"

  artwork_uri = RDF::URI.new("#{@rdf_prefixes[:cc].to_s}object/#{artwork_id}")
  @graph_artwork << [artwork_uri, RDF.type, @ecrm['E22_Man-Made_Object']]
  @graph_artwork << [artwork_uri, RDF.type, OWL.NamedIndividual]

  production_uri = RDF::URI.new("#{artwork_uri.to_s}/production")
  @graph_artwork << [production_uri, RDF.type, @ecrm[:E12_Production]]
  @graph_artwork << [production_uri, RDF.type, OWL.NamedIndividual]
  @graph_artwork << [production_uri, @ecrm[:P108_has_produced], artwork_uri]
  @graph_artwork << [artwork_uri, @ecrm[:P108i_was_produced_by], production_uri]

  titles = crawl_title(artwork_id)
  title_uri = RDF::URI.new("#{@rdf_prefixes[:cc].to_s}object/title/1")
  @graph_titles << [title_uri, RDF.type, @ecrm[:E35_Title]]
  @graph_titles << [title_uri, RDF.type, OWL.NamedIndividual]
  @graph_titles << [artwork_uri, @ecrm[:P102_has_title], title_uri]
  titles.each do |loc, title|
    @graph_titles << [artwork_uri, RDFS.label, RDF::Literal.new(title, :language => loc)]
    @graph_titles << [title_uri, RDFS.label, RDF::Literal.new(title, :language => loc)]
  end

  artwork_image_uri = RDF::URI.new(get_image_url(artwork_id))
  @graph_images << [artwork_image_uri, RDF.type, @ecrm[:E38_Image]]
  @graph_images << [artwork_image_uri, RDF.type, OWL.NamedIndividual]
  @graph_representation << [artwork_uri, @ecrm[:P138i_has_representation], artwork_image_uri]

  crawl_annotation(artwork_id).each do |localeLabel, annotation|
    unless annotation.empty?
      @graph_notes << [artwork_uri, @ecrm[:P3_has_note],
                       RDF::Literal.new(annotation, :language => localeLabel)]
    end
  end
}

puts
puts 'Writing files:'

puts '  graph_notes'
IO.write('rm_artwork_notes.ttl', @graph_notes.dump(:ttl, :prefixes => @rdf_prefixes))

puts '  graph_images'
IO.write('rm_artwork_images.ttl', @graph_images.dump(:ttl, :prefixes => @rdf_prefixes))

puts '  graph_artwork'
IO.write('rm_artwork_objects.ttl', @graph_artwork.dump(:ttl, :prefixes => @rdf_prefixes))

puts '  graph_representation'
IO.write('rm_artwork_representation.ttl', @graph_representation.dump(:ttl, :prefixes => @rdf_prefixes))

puts 'Done!'
