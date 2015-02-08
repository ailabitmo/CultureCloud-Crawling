# encoding: utf-8

require 'set'
require 'rubygems'
require 'io/console'
# require 'colorize'
# require 'pathname'

require 'net/http'
require 'uri'
#require 'json'

require 'nokogiri'
require 'rdf/turtle'
include RDF # Additional built-in vocabularies: http://rdf.greggkellogg.net/yard/RDF/Vocabulary.html
require 'rdf/xsd'
require 'securerandom'

def open_html(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 1
  http.read_timeout = 10
  begin
    response = http.get(uri.path)
  rescue Net::OpenTimeout
    puts 'Caught new Net::OpenTimeout exception.'
    retry
  end
  response.body
end

@host_url = "http://rmgallery.ru/"
@sections_labels = ["author","genre","type"] # TODO: "projects"-section with multiple images
BilingualLabel = Struct.new(:en, :ru)
@locale_labels = BilingualLabel.new("en","ru")
@annotation_labels = BilingualLabel.new("Annotation","Аннотация")

@ecrm_prefix = "http://erlangen-crm.org/current/"
@ecrm_vocabulary = RDF::Vocabulary(@ecrm_prefix)
@rdf_prefixes = {
    :ecrm =>  @ecrm_prefix,
    :rdf => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :dbp =>  "http://dbpedia.org/resource/",
    :owl => OWL.to_uri,
    'rm-lod' => "http://rm-lod.org/",
    'xsd' => XSD.to_uri
}

#TODO: move to common
def get_random_string
    SecureRandom.urlsafe_base64(5)
end

def get_image_url(object_id)
    urls = Hash.new
    urls[:rmgallery] = "#{@host_url}files/medium/#{object_id}_98.jpg"
    urls[:vismart] = "http://heritage.vismart.biz/image/#{object_id}.jpg"
    urls['rm-lod'] = "#{@rdf_prefixes['rm-lod']}image/#{object_id}"
    urls
end

def crawl_annotation(object_id)
    annotation = Hash.new
    @locale_labels.each { |locale_label|
        Nokogiri::HTML(open_html("#{@host_url}#{locale_label}/#{object_id}")).\
            css('div[data-role=collapsible]').each do |collapsible|
            if collapsible.css('h3').text.strip == @annotation_labels[locale_label]
            then
                a = collapsible.css('p').text
                annotation[locale_label] = a.strip unless a.empty?
            end
        end
    }
    annotation
end

def crawl_title_and_date(object_id)
    title_and_date = Hash.new
    title = Hash.new
    date = Hash.new
    @locale_labels.each { |locale_label|
        Nokogiri::HTML(open_html("#{@host_url}#{locale_label}/#{object_id}")).\
            css('div[data-role=content]').each do |content|
            t = content.css('h2[align=center]').text
            last_sentence = t.split(".").last
            if (last_sentence =~ /\d/) and (last_sentence!=t)
            then
                t.slice! last_sentence
                date[locale_label] = last_sentence.strip
            end
            title[locale_label] = t.strip unless t.empty?
        end
    }
    title_and_date[:title] = title
    title_and_date[:date] = date
    title_and_date
end

def crawl_description_and_sizes(object_id)
    description_and_sizes = Hash.new
    dimension = Set.new
    description = Hash.new
    diameter = String.new
    @locale_labels.each { |locale_label|
        art_item_html = Nokogiri::HTML(open_html(@host_url+locale_label+"/"+object_id))
        art_item_description_css = art_item_html.css("b").inner_html.split("<br>")
        art_item_description_css.shift
        art_item_description_css.each { |descr|
            already_parsed = false
            if descr=='20,8 x 11,1 x 9,5 ("Гармонист"); 21,4 x 12,7 x 10 ("Плясунья")'
            then
                puts 'TODO: Гармонист-плясунья'
                already_parsed = true
            elsif descr=='87 х 65 (овал, вписанный в прямоугольник)'
                dimensions = ['87', '65']
                dimension << dimensions
                already_parsed = true
            elsif descr=='Середина 1790-х71,5 x 56'
                dimensions = ['71.5', '56']
                dimension << dimensions
                already_parsed = true
            elsif !(descr.index('61,5 x51,5 (овал)').nil?)
                dimensions = ['61.5', '51.5']
                dimension << dimensions
                already_parsed = true
            elsif !(descr.index('46х 80').nil?)
                dimensions = ['46', '80']
                dimension << dimensions
                already_parsed = true
            elsif !(descr.index('140х168').nil?)
                dimensions = ['140', '168']
                dimension << dimensions
                already_parsed = true
            elsif !(descr.index('Диаметр ').nil?)
                diameter = descr.gsub!(',', '.')
                diameter.slice! 'Диаметр '
                already_parsed = true
            elsif !(descr.index('Высота – 22; верхний диаметр – 13,3; нижний диаметр – 13,9').nil?)
                puts 'TODO: Высота и диаметры'
                already_parsed = true
            elsif !(descr.index('Высота – 4; диаметр основания – 13; диаметр – 24,5').nil?)
                puts 'TODO: Высота и диаметры'
                already_parsed = true
            # ----
            elsif !(/\AИ.:.+; л.:.+\z/.match(descr).nil?)
            then
                puts 'TODO: с рамкой и без рамки?'
                descr = descr.split(";")[1].slice!(' л.:') # TODO: we should also use inner size somehow
            end
            unless already_parsed
            then
                #TODO: we should use regexps not this elsif-elsif-elsif...
                if !(descr.index(" х ").nil?)
                then
                    dimensions = descr.split("х")
                    dimensions.each_index { |i|
                        dimensions[i]=dimensions[i].strip.gsub(",", ".")
                    }
                    dimension << dimensions
                elsif !(descr.index(" x ").nil?)
                    dimensions = descr.split("x")
                    dimensions.each_index { |i|
                        dimensions[i]=dimensions[i].strip.gsub(",", ".")
                    }
                    dimension << dimensions
                elsif !(descr.index(" × ").nil?)
                    dimensions = descr.split("×")
                    dimensions.each_index { |i|
                        dimensions[i]=dimensions[i].strip.gsub(",", ".")
                    }
                    dimension << dimensions

                else
                    if description[locale_label].nil?
                    then
                        description[locale_label] = ""
                    end
                    description[locale_label] += descr.strip unless descr.empty?
                end
            end
        }
        #artItemDescription = art_item_description_css.join(". ")
    }
    if dimension.size>1
    then
        puts "Warning! Сontroversial size dimensions info in object: #{object_id}"
    elsif dimension.size>0
        width_height_depth=dimension.to_a[0]
        description_and_sizes[:sizes] = width_height_depth
    end
    description_and_sizes[:description] = description unless description.empty?
    description_and_sizes[:diameter] = diameter #unless diameter.empty?
    description_and_sizes
end

#crawlDescriptionAndSize("189")crawl_description_and_sizes('1081')
#crawl_title_and_date("189")
#gets

@graph_images = RDF::Graph.new(:format => :ttl)
@graph_artwork = RDF::Graph.new(:format => :ttl)
@graph_notes = RDF::Graph.new(:format => :ttl)
@graph_materials = RDF::Graph.new(:format => :ttl)
@graph_representation = RDF::Graph.new(:format => :ttl)
@graph_titles = RDF::Graph.new(:format => :ttl)
@graph_dates = RDF::Graph.new(:format => :ttl)

@artwork_ownerships_ttl = RDF::Graph.load('../results/rmgallery_artwork_ownerships.ttl')
@genres_ttl = RDF::Graph.load('../results/rmgallery_genres.ttl')

artworks_ids = Set.new
RDF::Query::Pattern.new(:s, @ecrm_vocabulary['P14_carried_out_by'], :o).execute(@artwork_ownerships_ttl).each { |statement|
    artworks_ids << /\d+/.match(statement.subject)[0]
}

#TODO: prepare materials
=begin
materials = Set.new
artworks_ids.to_a.each { |artworksId|
    xx = crawl_description_and_sizes(artworksId)[:description]
    puts xx
    materials << xx
}

puts '== Writing materials to file =='
puts
file = File.new('materials.txt', 'w')
file.write(materials.to_a)
file.close
puts 'Done!'
=end

artworks_ids.to_a.each { |artworksId|
    puts "artworkID: #{artworksId}"

    # Images
    current_artwork_uri = RDF::URI.new(get_image_url(artworksId)[:vismart])
    @graph_images << [current_artwork_uri,RDF.type,@ecrm_vocabulary[:E38_Image]]
    @graph_images << [current_artwork_uri,RDF.type,OWL.NamedIndividual]
    @graph_images << [current_artwork_uri,RDFS.label,RDF::URI.new(get_image_url(artworksId)[:rmgallery])]

    # Man-made-objects with notes
    new_man_made_object = RDF::URI.new("#{@rdf_prefixes['rm-lod']}object/#{artworksId}")
    @graph_artwork << [new_man_made_object,RDF.type,@ecrm_vocabulary['E22_Man-Made_Object']]
    @graph_artwork << [new_man_made_object,RDF.type,OWL.NamedIndividual]

    crawl_annotation(artworksId).each { |localeLabel, annotation|
        if annotation!=""
        then
            @graph_notes << [new_man_made_object,@ecrm_vocabulary[:P3_has_note],RDF::Literal.new(annotation, :language => localeLabel)]
        end

    }

    # Materials (todo) and dimensions

    current_description_and_sizes = crawl_description_and_sizes(artworksId)
    # TODO: new_man_made_object -- ecrm:P45_consists_of -- http://collection.britishmuseum.org/id/thesauri/x10489

    diameter = current_description_and_sizes[:diameter]
    unless diameter.empty?
    then
        dimension_label = "diameter"
        dimension_uri = RDF::URI.new("#{new_man_made_object.to_s}/#{dimension_label}/#{diameter}")
        @graph_materials << [dimension_uri, RDF.type, @ecrm_vocabulary['E54_Dimension']]
        @graph_materials << [dimension_uri, RDF.type, OWL.NamedIndividual]
        @graph_materials << [dimension_uri, @ecrm_vocabulary['P90_has_value'], RDF::Literal::Float.new(diameter)]
        bm_type_uri = RDF::URI.new("http://collection.britishmuseum.org/id/thesauri/dimension/#{dimension_label}")
        @graph_materials << [dimension_uri, @ecrm_vocabulary['P2_has_type'], bm_type_uri]
        @graph_materials << [new_man_made_object, @ecrm_vocabulary['P43_has_dimension'], dimension_uri]
    end
    current_sizes = current_description_and_sizes[:sizes]
    unless current_sizes.nil?
    then
        current_sizes.each_index { |i|
            dimension_label = String.new
            case i
                when 0 #width
                    dimension_label = "width"
                when 1 #height
                    dimension_label = "height"
                when 2 #depth
                    dimension_label = "depth"
                else
                    # type code here
                    puts 'something wrong with dimensions'
            end
            dimension_uri = RDF::URI.new("#{new_man_made_object.to_s}/#{dimension_label}/#{current_sizes[i]}")
            @graph_materials << [dimension_uri, RDF.type, @ecrm_vocabulary['E54_Dimension']]
            @graph_materials << [dimension_uri, RDF.type, OWL.NamedIndividual]
            @graph_materials << [dimension_uri, @ecrm_vocabulary['P90_has_value'], RDF::Literal::Float.new(current_sizes[i])]
            bm_type_uri = RDF::URI.new("http://collection.britishmuseum.org/id/thesauri/dimension/#{dimension_label}")
            @graph_materials << [dimension_uri, @ecrm_vocabulary['P2_has_type'], bm_type_uri]
            @graph_materials << [new_man_made_object, @ecrm_vocabulary['P43_has_dimension'], dimension_uri]
        }
    end

    # Representation
    @graph_representation << [new_man_made_object,@ecrm_vocabulary['P138i_has_representation'],current_artwork_uri]

    # Titles

    current_title_and_date = crawl_title_and_date(artworksId)
    current_title = current_title_and_date[:title]
    title_uri = RDF::URI.new("#{new_man_made_object.to_s}/title/1")
    @graph_titles << [new_man_made_object,@ecrm_vocabulary[:P102_has_title],title_uri]
    @graph_titles << [title_uri,RDF.type,@ecrm_vocabulary[:E35_Title]]
    @graph_titles << [title_uri,RDF.type,OWL.NamedIndividual]
    current_title.each { |localeLabel, title|
        title_literal = RDF::Literal.new(title, :language => localeLabel)
        @graph_titles << [title_uri,RDFS.label,title_literal]
        @graph_titles << [new_man_made_object,RDFS.label,title_literal]
    }

    # Dates

    current_date = current_title_and_date[:date]
    if current_date.size>0
    then
        production_uri = RDF::URI.new("#{new_man_made_object.to_s}/production")
        @graph_artwork << [production_uri,RDF.type,@ecrm_vocabulary[:E12_Production]]
        @graph_artwork << [production_uri,RDF.type,OWL.NamedIndividual]
        @graph_artwork << [production_uri,@ecrm_vocabulary[:P108_has_produced],new_man_made_object]
        @graph_artwork << [new_man_made_object,@ecrm_vocabulary[:P108i_was_produced_by], production_uri]
    end

}


#TODO: add option to select

puts
puts '== Writing files =='
puts

puts '== graph_notes =='
file = File.new('../results/rmgallery_artwork_notes.ttl', 'w')
file.write(@graph_notes.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== graph_images =='
file = File.new('../results/rmgallery_artwork_images.ttl', 'w')
file.write(@graph_images.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== graph_artwork =='
file = File.new('../results/rmgallery_artwork_objects.ttl', 'w')
file.write(@graph_artwork.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== graph_materials =='
file = File.new('../results/rmgallery_artwork_materials.ttl', 'w')
file.write(@graph_materials.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== graph_representation =='
file = File.new('../results/rmgallery_artwork_representation.ttl', 'w')
file.write(@graph_representation.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== graph_titles =='
file = File.new('../results/rmgallery_artwork_titles.ttl', 'w')
file.write(@graph_titles.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== graph_dates =='
file = File.new('../results/rmgallery_artwork_dates.ttl', 'w')
file.write(@graph_dates.dump(:ttl, :prefixes => @rdf_prefixes))
file.close
puts 'Done!'
