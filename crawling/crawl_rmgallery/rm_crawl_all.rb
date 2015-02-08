puts 'Executing scripts:'

puts '=========================================='
puts 'rm_crawl_artwork_ownerships'
require './rm_crawl_artwork_ownerships.rb'

puts '=========================================='
puts 'rm_crawl_artwork_dimensions'
require './rm_crawl_artwork_dimensions.rb'

puts '=========================================='
puts 'rm_crawl_genres'
require './rm_crawl_genres.rb'

puts '=========================================='
puts 'rm_crawl_dates'
require './rm_crawl_dates.rb'

puts '=========================================='
puts 'rm_crawl_authors'
require './rm_crawl_authors.rb'

puts '=========================================='
puts 'rm_crawl_artwork_dimensions.rb'
require './rm_crawl_artwork_dimensions.rb'

puts '=========================================='
puts 'rm_crawl_artworks'
require './rm_crawl_artworks.rb'


# we already downloaded all the images from rmgallery
# puts "\nrm_crawl_images\n"
# require './rm_crawl_images.rb'
