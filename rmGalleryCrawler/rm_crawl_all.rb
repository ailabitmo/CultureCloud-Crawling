puts '== Starting big script =='

puts '\nrm_crawl_artwork_ownerships\n'
require './rm_crawl_artwork_ownerships.rb'

puts '\nrm_crawl_genres\n'
require './rm_crawl_genres.rb'

puts 'rm_crawl_authors\n'
require './rm_crawl_authors.rb'

puts '\nrm_crawl_images\n'
require './rm_crawl_images.rb'

puts '\nrm_crawl_artworks\n'
require './rm_crawl_artworks.rb'
