require '../rm_crawl_common'
require 'sparql/client'
require 'json'

@sparql = SPARQL::Client.new('http://heritage.vismart.biz/sparql')

@queries = {
    :sameas_number =>
                      'SELECT DISTINCT ?rm_person WHERE {
                         ?rm_person a ecrm:E21_Person ;
                            owl:sameAs ?dbp_person .
                         ?dbp_person a dbpedia:Person
                      }',
    :influenced_rm_dbp =>
                      'SELECT DISTINCT ?rmA ?dbpA ?influenced WHERE {
                         ?rmA a ecrm:E21_Person ;
                            owl:sameAs ?dbpA .
                         ?dbpA dbpedia:influenced ?influenced .
                         ?influenced a dbpedia:Person
                      }',
    :influenced_rm_rm =>
                    'SELECT DISTINCT ?rmA ?dbpA ?rm_influenced WHERE {
                       ?rmA a ecrm:E21_Person ;
                          owl:sameAs ?dbpA .
                       ?dbpA dbpedia:influenced ?influenced .
                       ?influenced a dbpedia:Person .
                       ?rm_influenced owl:sameAs ?influenced .
                       ?rm_influenced a ecrm:E21_Person
                    }',
    :influencedby_rm_dbp =>
                    'SELECT DISTINCT ?rmA ?dbpA ?influencedBy WHERE {
                       ?rmA a ecrm:E21_Person ;
                          owl:sameAs ?dbpA .
                       ?dbpA dbpedia:influencedBy ?influencedBy .
                       ?influencedBy a dbpedia:Person
                    }',
    :influencedby_rm_rm =>
                    'SELECT DISTINCT ?rmA ?dbpA ?rm_influencedBy WHERE {
                         ?rmA a ecrm:E21_Person ;
                            owl:sameAs ?dbpA .
                         ?dbpA dbpedia:influencedBy ?influenced .
                         ?influenced a dbpedia:Person .
                         ?rm_influencedBy owl:sameAs ?influenced .
                         ?rm_influencedBy a ecrm:E21_Person
                      }'
}
puts 'Executing queries'
@queries.each do |stat, query|
  puts "#{stat}: #{@sparql.query(query).size}"
end
