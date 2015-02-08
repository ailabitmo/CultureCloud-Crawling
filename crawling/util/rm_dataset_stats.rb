require 'rdf/turtle'
require 'rdf/xsd'
require 'sparql/client'
require 'sparql'

@sparql = SPARQL::Client.new('http://localhost:9999/bigdata/sparql', :read_timeout => 3600)
# @sparql = SPARQL::Client.new('http://heritage.vismart.biz/sparql', :read_timeout => 3600)

@metrics  = {
    'General metrics' => {
        'Triples'           => 'SELECT (COUNT(*) AS ?no) { ?s ?p ?o }',
        'Classes'           => 'SELECT (COUNT(distinct ?o) AS ?no) { ?s rdf:type ?o }',
        'Properties'        => 'SELECT (COUNT(distinct ?p) as ?no) { ?s ?p ?o }',
        'Entities'          => 'SELECT (COUNT(distinct ?s) AS ?no) { ?s a [] }',
        'Distinct subjects' => 'SELECT (COUNT(DISTINCT ?s ) AS ?no) { ?s ?p ?o }',
        'Distinct objects'  => 'SELECT (COUNT(DISTINCT ?o ) AS ?no) { ?s ?p ?o  filter(!isLiteral(?o)) }',

        'Crawled artworks'  => 'SELECT (COUNT(DISTINCT ?s ) AS ?no) { ?s a <http://erlangen-crm.org/current/E22_Man-Made_Object> }',
        'Crawled authors'   => 'SELECT (COUNT(DISTINCT ?s ) AS ?no) { ?s a <http://erlangen-crm.org/current/E21_Person> }',
    },
    'Original dataset metrics' => {
        'Artwork descriptions'  => 'PREFIX ecrm: <http://erlangen-crm.org/current/>
                                    SELECT (COUNT(DISTINCT ?s) as ?no) {
                                      ?s a ecrm:E22_Man-Made_Object ;
                                         ecrm:P3_has_note []
                                    }',
        'Artwork dimension'     => 'PREFIX ecrm: <http://erlangen-crm.org/current/>
                                    SELECT (COUNT(DISTINCT ?s) as ?no) {
                                        ?s a ecrm:E22_Man-Made_Object ;
                                           ecrm:P43_has_dimension []
                                    }',
        'Artwork genre'         => 'PREFIX ecrm: <http://erlangen-crm.org/current/>
                                    SELECT (COUNT(DISTINCT ?s) as ?no) {
                                        ?s a ecrm:E22_Man-Made_Object ;
                                           ecrm:P2_has_type []
                                    }',
        'Artwork creation time' => 'PREFIX ecrm: <http://erlangen-crm.org/current/>
                                    SELECT (COUNT(DISTINCT ?s) as ?no) {
                                        ?s a ecrm:E12_Production ;
                                           ecrm:P4_has_time-span []
                                    }',
        "Author's bio"          => 'PREFIX ecrm: <http://erlangen-crm.org/current/>
                                    SELECT (COUNT(DISTINCT ?s) as ?no) {
                                        ?s a ecrm:E21_Person ;
                                           ecrm:P3_has_note []
                                    }',
    },
    'Interlinking metrics' => {
        'Number of interlinked authors [Total]' =>
            'PREFIX ecrm: <http://erlangen-crm.org/current/>
             SELECT (COUNT(DISTINCT ?s) as ?no) {
                 ?s a ecrm:E21_Person ;
                    owl:sameAs []
             }',
        'Number of interlinked authors [Ru]'    =>
            "PREFIX ecrm: <http://erlangen-crm.org/current/>
             SELECT (COUNT(DISTINCT ?s) as ?no) {
                 ?s a ecrm:E21_Person ;
                    owl:sameAs ?sameAs
                 FILTER(STRSTARTS(STR(?sameAs), 'http://dbpedia'))
             }",
        'Number of interlinked authors [En]'    =>
            "PREFIX ecrm: <http://erlangen-crm.org/current/>
             SELECT (COUNT(DISTINCT ?s) as ?no) {
                 ?s a ecrm:E21_Person ;
                    owl:sameAs ?sameAs
                 FILTER(STRSTARTS(STR(?sameAs), 'http://ru.dbpedia'))
             }",
        'Authors enriched with birth date'      =>
            'PREFIX ecrm: <http://erlangen-crm.org/current/>
             PREFIX dbpedia: <http://dbpedia.org/ontology/>
             SELECT (COUNT(DISTINCT ?s) as ?no) {
                 ?s a ecrm:E21_Person ;
                    owl:sameAs ?sameAs .
                 SERVICE <http://dbpedia.org/sparql> {
                 ?sameAs dbpedia:birthDate [] }
             }',
        'Authors enriched with death date'      =>
            'PREFIX ecrm: <http://erlangen-crm.org/current/>
             PREFIX dbpedia: <http://dbpedia.org/ontology/>
             SELECT (COUNT(DISTINCT ?s) as ?no) {
                 ?s a ecrm:E21_Person ;
                    owl:sameAs ?sameAs .
                 SERVICE <http://dbpedia.org/sparql> {
                 ?sameAs dbpedia:deathDate [] }
             }',
        'Authors enriched with birth place'     =>
            'PREFIX ecrm: <http://erlangen-crm.org/current/>
             PREFIX dbpedia: <http://dbpedia.org/ontology/>
             SELECT (COUNT(DISTINCT ?s) as ?no) {
                 ?s a ecrm:E21_Person ;
                    owl:sameAs ?sameAs .
                 SERVICE <http://dbpedia.org/sparql> {
                 ?sameAs dbpedia:birthPlace [] }
             }',
        'Authors enriched with death place'     =>
            'PREFIX ecrm: <http://erlangen-crm.org/current/>
             PREFIX dbpedia: <http://dbpedia.org/ontology/>
             SELECT (COUNT(DISTINCT ?s) as ?no) {
                 ?s a ecrm:E21_Person ;
                    owl:sameAs ?sameAs .
                 SERVICE <http://dbpedia.org/sparql> {
                 ?sameAs dbpedia:deathPlace [] }
             }',
        'Authors enriched with art movement'    =>
            'PREFIX ecrm: <http://erlangen-crm.org/current/>
             PREFIX dbpedia: <http://dbpedia.org/ontology/>
             SELECT (COUNT(DISTINCT ?s) as ?no) {
                 ?s a ecrm:E21_Person ;
                    owl:sameAs ?sameAs .
                 SERVICE <http://dbpedia.org/sparql> {
                 ?sameAs dbpedia:movement [] }
             }',
        'Authors enriched with <influenced>'    =>
            'PREFIX ecrm: <http://erlangen-crm.org/current/>
             PREFIX dbpedia: <http://dbpedia.org/ontology/>
             SELECT (COUNT(DISTINCT ?s) as ?no) {
                 ?s a ecrm:E21_Person ;
                    owl:sameAs ?sameAs .
                 SERVICE <http://dbpedia.org/sparql> {
                 ?sameAs dbpedia:influenced [] }
             }',
        'Authors enriched with <influenced by>' =>
            'PREFIX ecrm: <http://erlangen-crm.org/current/>
             PREFIX dbpedia: <http://dbpedia.org/ontology/>
             SELECT (COUNT(DISTINCT ?s) as ?no) {
                 ?s a ecrm:E21_Person ;
                    owl:sameAs ?sameAs .
                 SERVICE <http://dbpedia.org/sparql> {
                 ?sameAs dbpedia:influencedBy [] }
             }',
    }

}

puts '-----'

@metrics.each do |metric_group, metrics|
    puts metric_group
    metrics.each do |stat, query|
        print '  %s: ' % stat
        @sparql.query(query).each_solution do |solution|
            solution.each_value do |value|
                print value
            end
            print "\n"
        end
    end
end

puts '-----'
