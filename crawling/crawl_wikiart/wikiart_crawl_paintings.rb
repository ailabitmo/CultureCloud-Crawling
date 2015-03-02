# encoding: utf-8
require '../rm_crawl_common.rb'
require '../rm_enrich_common.rb'
require 'nokogiri'
require 'rdf/turtle'
require 'net/http'
require 'unicode'
require 'securerandom'
require 'digest/md5'
require 'json'
include RDF


file = File.read('our_authors.json')
authors_json = JSON.parse(file)

@host_url="http://www.wikiart.org"
@all_paintings_by_alphabet_suffix = "/mode/all-paintings-by-alphabet"

@cc_resource_object_prefix = "http://culturecloud.ru/resource/object"

@graph_dates = RDF::Graph.new(:format => :ttl)
@graph_dimensions = RDF::Graph.new(:format => :ttl)
@graph_images = RDF::Graph.new(:format => :ttl)
@graph_objects = RDF::Graph.new(:format => :ttl)
@graph_ownerships = RDF::Graph.new(:format => :ttl)
#@graph_annotations = RDF::Graph.new(:format => :ttl) #TODO: tags
#TODO: add concepts file
@graph_genres = RDF::Graph.new(:format => :ttl)
#@graph_genres_titles = RDF::Graph.new(:format => :ttl)

@genres_hash = {
    'abstract painting' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/abstraction'),
    'mythological painting' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x13025'),
    'marina' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x13032'),
    'battle painting' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12993'),
    'religious painting' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x13317'),
    'genre painting' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12718'),
    'illustration' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/illustration'),
    'design' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/design'),
    'history painting' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12859'),
    'landscape' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/x12934'),
    'portrait' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/portrait'),
    'veduta' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/veduta'),
    'cityscape' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/cityscape'),
    'flower painting' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/flower_painting'),
    'sketch and study' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/sketch_and_study'),
    'allegorical painting' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/allegorical_painting'),
    'self-portrait' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/portrait'), #TODO:
    'symbolic painting' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/symbolic_painting'),
    'nude painting (nu)' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/nude_painting'),
    'interior' => RDF::URI.new('http://culturecloud.ru/resource/thesauri/interior'),


}
genres_s = Set.new()

authors_json.each_key { |dbpedia_key|
  puts dbpedia_key
  wikiart_url=authors_json[dbpedia_key]['wikiart_url']
  all_paintings_css_body=Nokogiri::HTML(open_html(wikiart_url+@all_paintings_by_alphabet_suffix)).css('body')
  paintings_number=all_paintings_css_body.css('div[class="pager-total"]').text.match('Total: \d+').to_s.match('\d+').to_s.to_i
  pages_number=(paintings_number/60)

  if (paintings_number%60)>0
  then
    pages_number+=1
  end



  unless pages_number.nil?
    pages_number.times {|page_number|
      next_paining_page_url=wikiart_url+@all_paintings_by_alphabet_suffix+"/"+(page_number+1).to_s
      paintings_css_body=Nokogiri::HTML(open_html(next_paining_page_url)).css('body')
      search_items= paintings_css_body.css('div[id="paintings"]').css('div[class="Painting"]').css('div[class="search-row mr-20 small"]').\
      css('ins[class="search-item inline ie7_zoom"]').css('div[class="fl mr20"]')
      search_items.each { |search_item|
        search_item.css('p[class="pb5"] a').each { |link|
          painting_image_url = link.css('img').first['src'].sub('!xlSmall.jpg', '')
          painting_href = link['href']
          painting_title = link['title']
          title_no_spaces = painting_title.strip.gsub(' ','_').gsub('.','')
          if title_no_spaces.nil?
          then
            puts "title_no_spaces is nil"
            puts painting_title
            gets
          end

          #puts painting_image_url
          #puts @host_url+painting_href

          painting_css_body = Nokogiri::HTML(open_html(@host_url+painting_href)).css('body')

          #FIXME: more accurate search for a gallery maybe
          if painting_css_body.text.include?('Russian Museum, St. Petersburg, Russia')
          then
            painting_css_body.css('p[class="pt10 b0"]').each { |row_item|
              row_item_text=row_item.text.strip
              object_uri = RDF::URI.new("#{@cc_resource_object_prefix}/#{title_no_spaces}")
              #==========graph_dates
              production_postfix = "/production"
              production_uri = RDF::URI.new("#{object_uri.to_s}#{production_postfix}")
              date_postfix = "#{production_postfix}/date"
              date_uri = RDF::URI.new("#{object_uri.to_s}#{date_postfix}")
              start_date=""
              completion_date=""
              if row_item_text.start_with?("Start Date")
              then
                start_date=row_item_text.match(/[0-9]{4}/).to_s
                @graph_dates << [production_uri, @ecrm_vocabulary['P4_has_time-span'], date_uri]
                @graph_dates << [date_uri, RDF.type, @ecrm_vocabulary['E52_Time-Span']]
                @graph_dates << [date_uri, RDF.type, OWL.NamedIndividual]
                @graph_dates << [date_uri, @ecrm_vocabulary['P82a_begin_of_the_begin'],\
                  RDF::Literal.new(start_date, :datatype => RDF::XSD.date)]
              end
              if row_item_text.start_with?("Completion Date")
              then
                completion_date=row_item_text.match(/[0-9]{4}/).to_s
                @graph_dates << [production_uri, @ecrm_vocabulary['P4_has_time-span'], date_uri]
                @graph_dates << [date_uri, RDF.type, @ecrm_vocabulary['E52_Time-Span']]
                @graph_dates << [date_uri, RDF.type, OWL.NamedIndividual]
                @graph_dates << [date_uri, @ecrm_vocabulary['P82b_end_of_the_end'],\
                  RDF::Literal.new(completion_date, :datatype => RDF::XSD.date)]
              end
              if completion_date!="" && start_date!=""
              then
                if completion_date!=start_date
                then
                  #FIXME: dates_range not working
                  dates_range="#{start_date}-#{completion_date}"
                  puts "1"
                  puts dates_range
                  #FIXME: why to repeat date en and ru?
                  @graph_dates << [date_uri, RDFS.label, RDF::Literal.new(dates_range, :language => 'ru')]
                  @graph_dates << [date_uri, RDFS.label, RDF::Literal.new(dates_range, :language => 'en')]
                else
                  @graph_dates << [date_uri, RDFS.label, RDF::Literal.new(completion_date, :language => 'ru')]
                  @graph_dates << [date_uri, RDFS.label, RDF::Literal.new(completion_date, :language => 'en')]
                end
              end
              if completion_date=="" && start_date!=""
              then
                #FIXME: why to repeat date en and ru?
                puts "2"
                puts dates_range
                @graph_dates << [date_uri, RDFS.label, RDF::Literal.new(start_date, :language => 'ru')]
                @graph_dates << [date_uri, RDFS.label, RDF::Literal.new(start_date, :language => 'en')]
              end
              if start_date == "" && completion_date!=""
              then
                puts "3"
                puts dates_range
                @graph_dates << [date_uri, RDFS.label, RDF::Literal.new(completion_date, :language => 'ru')]
                @graph_dates << [date_uri, RDFS.label, RDF::Literal.new(completion_date, :language => 'en')]
              end
              #==========graph_dates end

              #==========graph_dimensions
              if row_item_text.start_with?("Dimension")
              then
                width = row_item_text.scan(/[\d\.]+/)[0]
                width_uri = RDF::URI.new("#{object_uri.to_s}/width/#{width}")
                height = row_item_text.scan(/[\d\.]+/)[1]
                height_uri = RDF::URI.new("#{object_uri.to_s}/height/#{height}")

                @graph_dimensions << [object_uri, @ecrm_vocabulary['P43_has_dimension'],width_uri]
                @graph_dimensions << [width_uri, RDF.type, @ecrm_vocabulary['E54_Dimension']]
                @graph_dimensions << [width_uri, RDF.type, OWL.NamedIndividual]
                @graph_dimensions << [width_uri, @ecrm_vocabulary['P2_has_type'],\
                 RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/dimension/width')]
                @graph_dimensions << [width_uri, @ecrm_vocabulary['P90_has_value'],\
                 RDF::Literal.new(width, :datatype => RDF::XSD.float)]

                @graph_dimensions << [object_uri, @ecrm_vocabulary['P43_has_dimension'],height_uri]
                @graph_dimensions << [height_uri, RDF.type, @ecrm_vocabulary['E54_Dimension']]
                @graph_dimensions << [height_uri, RDF.type, OWL.NamedIndividual]
                @graph_dimensions << [height_uri, @ecrm_vocabulary['P2_has_type'],\
                 RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/dimension/height')]
                @graph_dimensions << [height_uri, @ecrm_vocabulary['P90_has_value'],\
                 RDF::Literal.new(height, :datatype => RDF::XSD.float)]
              end
              #==========graph_dimensions end

              #==========graph_images
              #FIXME: should we save all the images from wikiart?
              painting_image_uri = RDF::URI.new(painting_image_url)
              @graph_images << [painting_image_uri,RDF.type,@ecrm_vocabulary['E38_Image']]
              @graph_images << [painting_image_uri,RDF.type,OWL.NamedIndividual]
              #==========graph_images end
              #==========graph_objects
              @graph_objects << [object_uri,RDF.type,@ecrm_vocabulary['E22_Man-Made_Object']]
              @graph_objects << [object_uri,RDF.type,OWL.NamedIndividual]
              title_uri=RDF::URI.new("#{object_uri}/title/1")
              @graph_objects << [object_uri, @ecrm_vocabulary['P102_has_title'],title_uri]
              @graph_objects << [object_uri, @ecrm_vocabulary['P108i_was_produced_by'], production_uri]
              @graph_objects << [object_uri, @ecrm_vocabulary['P138i_has_representation'], painting_image_uri]

              @graph_objects << [production_uri, RDF.type, @ecrm_vocabulary['E12_Production']]
              @graph_objects << [production_uri,RDF.type,OWL.NamedIndividual]
              @graph_objects << [production_uri, @ecrm_vocabulary['P108_has_produced'], object_uri]

              @graph_objects << [title_uri, RDF.type, @ecrm_vocabulary['E35_Title']]
              @graph_objects << [title_uri,RDF.type,OWL.NamedIndividual]
              @graph_objects << [title_uri,RDFS.label,RDF::Literal.new(painting_title.to_s.strip, :language => 'en')]
              #==========graph_objects end

              #==========graph_ownership
              @graph_ownerships << [production_uri,@ecrm_vocabulary['P14_carried_out_by'],RDF::URI.new(dbpedia_key)]
              #==========graph_ownership end

              #==========graph_genres
              if row_item_text.start_with?("Genre:")
              then
                genres_string=row_item_text.sub('Genre:','').strip
                genre_uri = @genres_hash[genres_string]
                if genre_uri.nil?
                then
                  genres_s.add(genres_string)
                else
                  @graph_genres << [object_uri,@ecrm_vocabulary['P2_has_type'],genre_uri]
                end
              end
              #==========graph_genres end
              #==========graph_genres titles
              #TODO:
              #==========graph_genres titles end

            }
          end

        }
      }
    }
  end
}

puts genres_s.to_a
#gets


puts
puts '== Writing files =='
puts
file_dates = File.new('../results/wikiart_artwork_dates.ttl', 'w')
file_dates.write(@graph_dates.dump(:ttl, :prefixes => @rdf_prefixes))
file_dates.close

file_dimensions = File.new('../results/wikiart_artwork_dimensions.ttl', 'w')
file_dimensions.write(@graph_dimensions.dump(:ttl, :prefixes => @rdf_prefixes))
file_dimensions.close

file_images = File.new('../results/wikiart_artwork_images.ttl', 'w')
file_images.write(@graph_images.dump(:ttl, :prefixes => @rdf_prefixes))
file_images.close

file_objects = File.new('../results/wikiart_artwork_objects.ttl', 'w')
file_objects.write(@graph_objects.dump(:ttl, :prefixes => @rdf_prefixes))
file_objects.close

file_ownerships = File.new('../results/wikiart_artwork_ownerships.ttl', 'w')
file_ownerships.write(@graph_ownerships.dump(:ttl, :prefixes => @rdf_prefixes))
file_ownerships.close

file_genres = File.new('../results/wikiart_artwork_genres.ttl', 'w')
file_genres.write(@graph_genres.dump(:ttl, :prefixes => @rdf_prefixes))
file_genres.close