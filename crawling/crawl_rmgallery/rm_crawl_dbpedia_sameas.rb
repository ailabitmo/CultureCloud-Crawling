# encoding: utf-8
require './rm_crawl_common'
require 'sparql/client'
require 'json'
include RDF

@dbpedia_persons = Hash.new
@rm_persons = Hash.new

# @dbpedia_persons = JSON.parse(IO.read('dbpedia_persons.json'))
# @rm_persons = JSON.parse(IO.read('rm_persons.json'))
def save_json
  File.open('dbpedia_persons.json', 'w') do |f|
    f << JSON.pretty_generate(@dbpedia_persons)
  end
  File.open('rm_persons.json', 'w') do |f|
    f << JSON.pretty_generate(@rm_persons)
  end
end

def write_to_hash(hash, solution)
  person_uri = solution[:person].to_s
  label = solution[:label].to_s
  hash[person_uri] = label
end

sparql = SPARQL::Client.new('http://heritage.vismart.biz/sparql')

puts 'Querying DBPedia persons'
result = sparql.query('
  SELECT DISTINCT ?person ?label WHERE {
    ?person a dbpedia:Painter ;
            rdfs:label ?label
            FILTER(langMatches(lang(?label), "ru"))
  }')

result.each_solution do |s|
  write_to_hash(@dbpedia_persons, s)
end

puts 'Querying RM persons'
result = sparql.query('
  SELECT DISTINCT ?person ?label WHERE {
    ?person a ecrm:E21_Person ;
            rdfs:label ?label
            FILTER(langMatches(lang(?label), "ru"))
  }')

result.each_solution do |s|
  write_to_hash(@rm_persons, s)
end

# save_json

@name_pattern = /^([[[:alpha:]]- ]+), ([[:alpha:]]+) ([[:alpha:]]+)/
@name_pattern_no_patronymic = /^([[[:alpha:]]-]+), ([[:alpha:]]+) ([[:alpha:]]+)/

def get_initials(person_label)
  m = @name_pattern.match(person_label)
  return "#{m[1]} #{m[2][0,1]}.#{m[3][0,1]}." unless m.nil?
  m = @name_pattern_no_patronymic.match(person_label)
  return "#{m[1]} #{m[2][0,1]}" unless m.nil?
  nil
end

puts 'Matching strings'
@linked = Hash.new
@unlinked = Hash.new
@rm_persons.each do |rm_person_uri, rm_person_label|
  @is_linked = false
  @dbpedia_persons.each do |dbp_person_uri, dbp_person_label|
    dbp_person_initials = get_initials(dbp_person_label)
    next if dbp_person_initials.nil?

    if dbp_person_initials == rm_person_label
      @linked[rm_person_uri] = [] if @linked[rm_person_uri].nil?
      @linked[rm_person_uri] << dbp_person_uri
      @is_linked = true
    end
  end
  @unlinked[rm_person_uri] = rm_person_label unless @is_linked
end

puts 'Writing graph'
@graph = RDF::Graph.new(:format => :ttl)
@linked.each do |rm_person_uri, dbp_person_uri|
  dbp_person_uri.each do |sameAs|
      @graph << [RDF::URI.new(rm_person_uri), OWL.sameAs, RDF::URI.new(sameAs)]
  end
end
File.open('rm_persons_sameas.ttl', 'w') do |f|
  f << @graph.dump(:ttl, :prefixes => @rdf_prefixes)
end

puts "\nLinked persons: #{@linked.size}/#{@rm_persons.size}"
puts 'Unlinked:'
@unlinked.each do |k,v|
  puts "  <#{k}> #{v}"
end