# encoding: utf-8

require 'set'
require 'rubygems'
require 'io/console'
require 'pathname'
require 'open-uri'
require 'rdf'
require 'rdf/turtle'

@ecrm_prefix = "http://erlangen-crm.org/current/"
@ecrm_vocabulary = RDF::Vocabulary(@ecrm_prefix)
@artwork_ownerships_ttl = RDF::Graph.load('../results/rmgallery_artwork_ownerships.ttl')
@genres_ttl = RDF::Graph.load('../results/rmgallery_genres.ttl')

puts "rm_genres.ttl and rm_artwork_ownerships.ttl should be in the same folder"
puts "enter save path:"
savepath = gets.strip
if File.directory? File.expand_path(savepath)
    artworks_ids = Set.new
    RDF::Query::Pattern.new(:s, @ecrm_vocabulary['P14_carried_out_by'], :o).execute(@artwork_ownerships_ttl).each { |statement|
        artworks_ids << /\d+/.match(statement.subject)[0]
    }
    i=1
    artworks_ids.to_a.each { |artworksId|
        puts "#{i}.artworkID: #{artworksId}"
        if savepath[-1, 1]=="/"
        then
            savepath.chop!                  
        end
        File.open("#{File.expand_path(savepath)}/#{artworksId}.jpg", "wb") do |saved_file|
          # the following "open" is provided by open-uri
          open("http://rmgallery.ru/files/medium/#{artworksId}_98.jpg", "rb") do |read_file|
            saved_file.write(read_file.read)
          end
        end
        i+=1
    }
else
    puts "directory is not exists"
end
