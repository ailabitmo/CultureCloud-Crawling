puts '== Starting main big script =='

puts "\nrmgallery_crawl_artwork_ownerships\n"
require './rmgallery_crawl_artwork_ownerships.rb'

puts "\nrmgallery_crawl_genres\n"
require './rmgallery_crawl_genres.rb'

puts "rmgallery_crawl_authors\n"
require './rmgallery_crawl_authors.rb'

# we already crawled all the images from rmgallery
# puts "\nrm_crawl_images\n"
# require './rm_crawl_images.rb'

puts "\nrmgallery_crawl_artwork_dimensions.rb\n"
require './rmgallery_crawl_artwork_dimensions.rb'

puts "\nrmgallery_crawl_artworks\n"
require './rmgallery_crawl_artworks.rb'

puts "\nrmgallery_crawl_dates\n"
require './rmgallery_crawl_dates.rb'

puts "\nrmgallery_enrichment_builder\n"
require './rmgallery_enrichment_builder.rb'
