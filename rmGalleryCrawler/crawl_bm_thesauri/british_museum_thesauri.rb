require 'json'
require 'rdf/turtle'
include RDF

RDF

json = JSON.parse(IO.read('bm_dimension.json'))
bm_dim = json['results']['bindings']
json = JSON.parse(IO.read('bm_material.json'))
bm_mat = json['results']['bindings']
json = JSON.parse(IO.read('bm_subject.json'))
bm_subj = json['results']['bindings']

@rdf_prefixes = {
    :skos => RDF::URI.new('http://www.w3.org/2004/02/skos/core#'),
    :rdf => RDF.to_uri,
    :rdfs => RDFS.to_uri,
    :owl => OWL.to_uri,
    :ecrm => RDF::URI.new('http://erlangen-crm.org/current/'),
    :bmthes => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/')
}

@uri = {
    'skos:inScheme' => RDF::URI.new('http://www.w3.org/2004/02/skos/core#inScheme'),
    'skos:Concept' => RDF::URI.new('http://www.w3.org/2004/02/skos/core#Concept'),
    'bmthes:dimension' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/dimension'),
    'bmthes:material' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/material'),
    'bmthes:subj' => RDF::URI.new('http://collection.britishmuseum.org/id/thesauri/subject'),
    'ecrm:E57_Material' => RDF::URI.new('http://erlangen-crm.org/current/E57_Material'),
    'ecrm:E54_Dimension' => RDF::URI.new('http://erlangen-crm.org/current/E54_Dimension'),
    'ecrm:E55_Type' => RDF::URI.new('http://erlangen-crm.org/current/E55_Type'),
}

@graph = RDF::Graph.new(:format => :ttl, :prefixes => @rdf_prefixes)


def add_to_graph(bindings, skos_in_scheme, ecrm_type)
    bindings.each do |statement|
        s = RDF::URI.new(statement['s']['value'])
        p = RDF::URI.new(statement['p']['value'])
        if statement['o']['type'] == 'uri'
            o = RDF::URI.new(statement['o']['value'])
        else
            o = RDF::Literal.new(statement['o']['value'], :language => :en)
        end
        @graph << [s,p,o]
        @graph << [s, @uri['skos:inScheme'], skos_in_scheme]
        @graph << [s, RDF.type, @uri['skos:Concept']]
        @graph << [s, RDF.type, ecrm_type]
    end
end

puts 'add_to_graph'
add_to_graph(bm_dim, @uri['bmthes:dimension'], @uri['ecrm:E54_Dimension'])
puts 'add_to_graph'
add_to_graph(bm_mat, @uri['bmthes:material'], @uri['ecrm:E57_Material'])
puts 'add_to_graph'
add_to_graph(bm_subj, @uri['bmthes:subj'], @uri['ecrm:E55_Type'])

puts 'Writing file'
file = File.new('bm_thesauri.ttl', 'w')
file.write(@graph.dump(:ttl, :prefixes => @rdf_prefixes))
file.close

puts 'Done'
