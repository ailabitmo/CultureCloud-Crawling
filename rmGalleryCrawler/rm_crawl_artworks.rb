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

def openHtml(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 1
  http.read_timeout = 10
  begin
    response = http.get(uri.path)
  rescue Net::OpenTimeout
    puts 'Catched new Net::OpenTimeout exception. Press return to retry (recommended) or Ctrl+C to interrupt (the data will be lost in that case).'
    retry
  end
  return response.body
end

@hostUrl = "http://rmgallery.ru/"
@sectionsLabels = ["author","genre","type"] # TODO: "projects"-section with multiple images
BilingualLabel = Struct.new(:en, :ru)
@localeLabels = BilingualLabel.new("en","ru")
@annotationLabels = BilingualLabel.new("Аnnotation","Аннотация")

@ecrmPrefix = "http://erlangen-crm.org/current/"
@ecrmVocabulary = RDF::Vocabulary.new(@ecrmPrefix)
@rdf_prefixes = {
    :ecrm =>  @ecrmPrefix,
    :rdf => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :dbp =>  "http://dbpedia.org/resource/",
    :owl => OWL.to_uri,
    'rm-lod' => "http://rm-lod.org/",
    'xsd' => XSD.to_uri
}

def getRandomString()
    return SecureRandom.urlsafe_base64(5)
end

def getImageUrl(objectId)
    urls = Hash.new
    urls[:rmgallery] = "#{@hostUrl}files/medium/#{objectId}_98.jpg"
    urls[:vismart] = "http://heritage.vismart.biz/image/#{objectId}.jpg"
    urls['rm-lod'] = "#{@rdf_prefixes['rm-lod']}image/#{objectId}"
    return urls
end

def crawlAnnotation(objectId)
    annotation = Hash.new
    @localeLabels.each { |localeLabel|
        Nokogiri::HTML(openHtml("#{@hostUrl}#{localeLabel}/#{objectId}")).\
            css('div[data-role=collapsible]').each do |collapsible|
            if collapsible.css('h3').text == @annotationLabels[localeLabel]
                a = collapsible.css('p').text
                annotation[localeLabel] = a.strip unless a.empty?
            end
        end
    }
    return annotation
end

def crawlTitleAndDate(objectId)
    titleAndDate = Hash.new
    title = Hash.new
    date = Hash.new
    @localeLabels.each { |localeLabel|
        Nokogiri::HTML(openHtml("#{@hostUrl}#{localeLabel}/#{objectId}")).\
            css('div[data-role=content]').each do |content|
            t = content.css('h2[align=center]').text
            re = /\d+/
            lastSentense = t.split(".").last
            if (lastSentense =~ /\d/) and (lastSentense!=t)
            then
                t.slice! lastSentense
                date[localeLabel] = lastSentense.strip
            end
            title[localeLabel] = t.strip unless t.empty?
        end
    }
    titleAndDate[:title] = title
    titleAndDate[:date] = date
    return titleAndDate
end

def crawlDescriptionAndSizes(objectId)
    descriptionAndSizes = Hash.new
    dimention = Set.new
    description = Hash.new
    diameter = String.new
    @localeLabels.each { |localeLabel|
        artItemHTML = Nokogiri::HTML(openHtml(@hostUrl+localeLabel+"/"+objectId))
        artItemDescriptionCss = artItemHTML.css("b").inner_html.split("<br>")
        artItemDescriptionCss.shift
        artItemDescriptionCss.each { |descr|
            already_parsed = false
            if (descr=='20,8 x 11,1 x 9,5 ("Гармонист"); 21,4 x 12,7 x 10 ("Плясунья")')
            then
                puts "TODO: Гармонист-плясунья"
                already_parsed = true
            elsif (descr=="87 х 65 (овал, вписанный в прямоугольник)")
                dimentions = ["87","65"]
                dimention << dimentions
                already_parsed = true
            elsif (descr=="Середина 1790-х71,5 x 56")
                dimentions = ["71.5","56"]
                dimention << dimentions
                already_parsed = true
            elsif !(descr.index("61,5 x51,5 (овал)").nil?)
                dimentions = ["61.5","51.5"]
                dimention << dimentions
                already_parsed = true
            elsif !(descr.index("46х 80").nil?)
                dimentions = ["46","80"]
                dimention << dimentions
                already_parsed = true
            elsif !(descr.index("140х168").nil?)
                dimentions = ["140","168"]
                dimention << dimentions
                already_parsed = true
            elsif !(descr.index("Диаметр ").nil?)
                diameter = descr.gsub!(",",".")
                diameter.slice! "Диаметр "
                already_parsed = true
            elsif !(descr.index("Высота – 22; верхний диаметр – 13,3; нижний диаметр – 13,9").nil?)
                puts "TODO: Высота и диаметры"
                already_parsed = true
            elsif !(descr.index("Высота – 4; диаметр основания – 13; диаметр – 24,5").nil?)
                puts "TODO: Высота и диаметры"
                already_parsed = true
            # ----
            elsif !(/\AИ.:.+; л.:.+\z/.match(descr).nil?)
            then
                puts "TODO: с рамкой и без рамки?"
                descr = descr.split(";")[1].slice!(' л.:') # TODO: we should also use inner size somehow
            end
            if (!already_parsed) then
                #TODO: we should use regexps not this elsif-elsif-elsif...
                if !(descr.index(" х ").nil?)
                then
                    dimentions = descr.split("х")
                    dimentions.each_index { |i|
                        dimentions[i]=dimentions[i].strip.gsub(",",".")
                    }
                    dimention << dimentions
                elsif !(descr.index(" x ").nil?)
                    dimentions = descr.split("x")
                    dimentions.each_index { |i|
                        dimentions[i]=dimentions[i].strip.gsub(",",".")
                    }
                    dimention << dimentions
                elsif !(descr.index(" × ").nil?)
                    dimentions = descr.split("×")
                    dimentions.each_index { |i|
                        dimentions[i]=dimentions[i].strip.gsub(",",".")
                    }
                    dimention << dimentions

                else
                    if description[localeLabel].nil?
                    then
                        description[localeLabel] = ""
                    end
                    description[localeLabel] += descr.strip unless descr.empty?
                end
            end
        }
        #artItemDescription = artItemDescriptionCss.join(". ")
    }
    if (dimention.size>1)
    then
        puts "Warning! Сontroversial size dimentions info in object: #{objectId}"
    elsif (dimention.size>0)
        widthHeightDepth=dimention.to_a[0]
        descriptionAndSizes[:sizes] = widthHeightDepth
    end
    descriptionAndSizes[:decription] = description unless description.empty?
    descriptionAndSizes[:diameter] = diameter #unless diameter.empty?
    return descriptionAndSizes
end

#crawlDescriptionAndSize("189")crawlDescriptionAndSizes('1081')
#crawlTitleAndDate("189")
#gets

@graph_images = RDF::Graph.new(:format => :ttl)
@graph_artwork = RDF::Graph.new(:format => :ttl)
@graph_materials = RDF::Graph.new(:format => :ttl)
@graph_representation = RDF::Graph.new(:format => :ttl)
@graph_titles = RDF::Graph.new(:format => :ttl)
@graph_dates = RDF::Graph.new(:format => :ttl)

@artwork_ownerships_ttl = RDF::Graph.load('rm_artwork_ownerships.ttl')
@genres_ttl = RDF::Graph.load('rm_genres.ttl')

artworksIds = Set.new
RDF::Query::Pattern.new(:s, @ecrmVocabulary['P14_carried_out_by'], :o).execute(@artwork_ownerships_ttl).each { |statement|
    artworksIds << /\d+/.match(statement.subject)[0]
}

#TODO: prepare materials
=begin
materials = Set.new
artworksIds.to_a.each { |artworksId|
    xx = crawlDescriptionAndSizes(artworksId)[:decription]
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

artworksIds.to_a.each { |artworksId|
    puts "artworkID: #{artworksId}"

    # Images
    currentArtworkURI = RDF::URI.new(getImageUrl(artworksId)[:vismart])
    @graph_images << [currentArtworkURI,RDF.type,@ecrmVocabulary[:E38_Image]]
    @graph_images << [currentArtworkURI,RDF.type,OWL.NamedIndividual]
    @graph_images << [currentArtworkURI,RDFS.label,RDF::URI.new(getImageUrl(artworksId)[:rmgallery])]

    # Man-made-objects with notes
    newManMadeObject = RDF::URI.new("#{@rdf_prefixes['rm-lod']}object/#{artworksId}")
    @graph_artwork << [newManMadeObject,RDF.type,@ecrmVocabulary['E22_Man-Made_Object']]
    @graph_artwork << [newManMadeObject,RDF.type,OWL.NamedIndividual]

    crawlAnnotation(artworksId).each { |localeLabel, annotation|
        @graph_artwork << [newManMadeObject,@ecrmVocabulary[:P3_has_note],RDF::Literal.new(annotation, :language => localeLabel)]
    }

    # Materials (todo) and dimentions

    currentDescriptionAndSizes = crawlDescriptionAndSizes(artworksId)
    # TODO: newManMadeObject -- ecrm:P45_consists_of -- http://collection.britishmuseum.org/id/thesauri/x10489

    diameter = currentDescriptionAndSizes[:diameter]
    if !(diameter.empty?)
    then
        dimentionLabel = "diameter"
        dimentionURI = RDF::URI.new("#{newManMadeObject.to_s}/#{dimentionLabel}/#{diameter}")
        @graph_materials << [dimentionURI,RDF.type,@ecrmVocabulary['E54_Dimension']]
        @graph_materials << [dimentionURI,RDF.type,OWL.NamedIndividual]
        @graph_materials << [dimentionURI,@ecrmVocabulary['P90_has_value'], RDF::Literal::Float.new(diameter)]
        bmTypeURI = RDF::URI.new("http://collection.britishmuseum.org/id/thesauri/dimension/#{dimentionLabel}")
        @graph_materials << [dimentionURI,@ecrmVocabulary['P2_has_type'],bmTypeURI]
        @graph_materials << [newManMadeObject,@ecrmVocabulary['P43_has_dimension'],dimentionURI]
    end
    currentSizes = currentDescriptionAndSizes[:sizes]
    if !(currentSizes.nil?)
    then
        currentSizes.each_index { |i|
            dimentionLabel = String.new
            case i
                when 0 #width
                    dimentionLabel = "width"
                when 1 #height
                    dimentionLabel = "height"
                when 2 #depth
                    dimentionLabel = "depth"
            end
            dimentionURI = RDF::URI.new("#{newManMadeObject.to_s}/#{dimentionLabel}/#{currentSizes[i]}")
            @graph_materials << [dimentionURI,RDF.type,@ecrmVocabulary['E54_Dimension']]
            @graph_materials << [dimentionURI,RDF.type,OWL.NamedIndividual]
            @graph_materials << [dimentionURI,@ecrmVocabulary['P90_has_value'], RDF::Literal::Float.new(currentSizes[i])]
            bmTypeURI = RDF::URI.new("http://collection.britishmuseum.org/id/thesauri/dimension/#{dimentionLabel}")
            @graph_materials << [dimentionURI,@ecrmVocabulary['P2_has_type'],bmTypeURI]
            @graph_materials << [newManMadeObject,@ecrmVocabulary['P43_has_dimension'],dimentionURI]
        }
    end

    # Representation
    @graph_representation << [newManMadeObject,@ecrmVocabulary['P138i_has_representation'],currentArtworkURI]

    # Titles

    currentTitleAndDate = crawlTitleAndDate(artworksId)
    currentTitle = currentTitleAndDate[:title]
    titleURI = RDF::URI.new("#{newManMadeObject.to_s}/title/1")
    @graph_titles << [newManMadeObject,@ecrmVocabulary[:P102_has_title],titleURI]
    @graph_titles << [titleURI,RDF.type,@ecrmVocabulary[:E35_Title]]
    @graph_titles << [titleURI,RDF.type,OWL.NamedIndividual]
    currentTitle.each { |localeLabel, title|
        titleLiteral = RDF::Literal.new(title, :language => localeLabel)
        @graph_titles << [titleURI,RDFS.label,titleLiteral]
        @graph_titles << [newManMadeObject,RDFS.label,titleLiteral]
    }

    # Dates

    currentDate = currentTitleAndDate[:date]
    if (currentDate.size>0)
    then
        productionURI = RDF::URI.new("#{newManMadeObject.to_s}/production")
        @graph_artwork << [productionURI,RDF.type,@ecrmVocabulary[:E12_Production]]
        @graph_artwork << [productionURI,RDF.type,OWL.NamedIndividual]
        @graph_artwork << [productionURI,@ecrmVocabulary[:P108_has_produced],newManMadeObject]
        @graph_artwork << [newManMadeObject,@ecrmVocabulary[:P108i_was_produced_by], productionURI]
    end

}



puts
puts '== Writing files =='
puts

puts '== graph_images =='
file = File.new('rm_artwork_images.ttl', 'w')
file.write(@graph_images.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== graph_artwork =='
file = File.new('rm_artwork_objects.ttl', 'w')
file.write(@graph_artwork.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== graph_materials =='
file = File.new('rm_artwork_materials.ttl', 'w')
file.write(@graph_materials.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== graph_representation =='
file = File.new('rm_artwork_representation.ttl', 'w')
file.write(@graph_representation.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== graph_titles =='
file = File.new('rm_artwork_titles.ttl', 'w')
file.write(@graph_titles.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts '== graph_dates =='
file = File.new('rm_artwork_dates.ttl', 'w')
file.write(@graph_dates.dump(:ttl, :prefixes => @rdf_prefixes))
file.close
puts 'Done!'
