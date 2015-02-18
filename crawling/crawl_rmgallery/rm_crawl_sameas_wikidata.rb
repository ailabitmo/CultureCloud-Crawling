# encoding: utf-8
require 'rdf/xsd'
require 'rdf/turtle'
require 'sparql'
require 'sparql/client'

include RDF

@sparql_dbp = SPARQL::Client.new('http://dbpedia.org/sparql', :read_timout => 300)
@sparql_cc = SPARQL::Client.new('http://culturecloud.ru/sparql', :read_timout => 300)

def get_cc_authors()
  query = '
    PREFIX ecrm: <http://erlangen-crm.org/current/>
    PREFIX owl: <http://www.w3.org/2002/07/owl#>
    SELECT DISTINCT ?person ?sameAs WHERE {
    ?person a ecrm:E21_Person ;
      owl:sameAs ?sameAs .
  }'
  authors = Hash.new
  @sparql_cc.query(query).each_solution do |s|
    authors[s[:person].to_s] = [] if authors[s[:person].to_s].nil?
    authors[s[:person].to_s] << s[:sameAs].to_s
  end
  authors
end

@dbp_authors = get_cc_authors

def dbp_get_author(author)
  query = "
    PREFIX owl: <http://www.w3.org/2002/07/owl#>
    SELECT DISTINCT ?sameAs WHERE {
      <%s> owl:sameAs ?sameAs
    }"
  author_dbp = ""
  author_wikidata = ""
  if author.start_with?("http://ru.dbpedia")
    @sparql_dbp.query(query % author).each_solution do |s|
      author_dbp = s[:sameAs].to_s if s[:sameAs].start_with?("http://dbpedia")
    end
  else
    author_dbp = author
  end

  return nil if author_dbp.empty?

  @sparql_dbp.query(query % author_dbp).each_solution do |s|
    same_as = s[:sameAs].to_s
    if same_as.start_with?("http://wikidata.dbpedia.org/resource/")
      author_wikidata =  "http://www.wikidata.org/entity/#{same_as[37..same_as.length]}"
      break
    elsif same_as.start_with?("http://wikidata.org/entity/")
      author_wikidata = "http://www.wikidata.org/entity/#{same_as[27..same_as.length]}"
      break
    elsif same_as.start_with?("http://www.wikidata.org/entity/")
      author_wikidata = same_as
      break
    end
  end

  return nil if author_wikidata.empty?
  author_wikidata
end

@cc_wikidata = {}
@dbp_authors.each do |cc_author, dbp_author|
  wd = nil
  dbp_author.each do |a|
    wd = dbp_get_author(a)
    sleep(0.5)
    break unless wd.nil?
  end
  @cc_wikidata[cc_author] = wd
end

@cc_wikidata_ttl = RDF::Graph.new(:format => :ttl)
@cc_wikidata.each do |cc_author, wikidata_author|
  next if wikidata_author.nil?
  s = RDF::URI.new(cc_author)
  p = OWL.sameAs
  o = RDF::URI.new(wikidata_author)
  @cc_wikidata_ttl << [s, p, o]
end

@rdf_prefixes = {
  :cc_person => 'http://culturecloud.ru/resource/person/',
  :wd => 'http://www.wikidata.org/entity/',
  :owl => OWL.to_uri
}

File.open('rm_persons_sameas_wikidata.ttl', 'w') do |f|
  f << @cc_wikidata_ttl.dump(:ttl, :prefixes => @rdf_prefixes)
end
