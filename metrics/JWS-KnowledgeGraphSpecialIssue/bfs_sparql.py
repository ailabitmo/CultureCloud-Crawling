from SPARQLWrapper import SPARQLWrapper, JSON, SPARQLExceptions
import cjson

# Only crawled ang generated data
sparql_dbp = SPARQLWrapper('http://dbpedia.org/sparql')
sparql_dbp.setReturnFormat(JSON)

# Endpoint with Wikidata
sparql_wd = SPARQLWrapper('http://wikidata.metaphacts.com:8080/bigdata/sparql')
sparql_wd.setReturnFormat(JSON)

sparql_raw = SPARQLWrapper('http://localhost:9999/bigdata/namespace/raw/sparql')
sparql_raw.setReturnFormat(JSON)

sparql_cc = SPARQLWrapper('http://localhost:9999/bigdata/sparql')
sparql_cc.setReturnFormat(JSON)

# All except 'ru' and 'en'
wikipedia_languages = ['de', 'fr', 'nl', 'it', 'es', 'sv', 'pl', 'war',
                       'vi', 'ceb', 'ja', 'pt', 'ar', 'zh', 'uk', 'ca', 'no', 'fi',
                       'cs', 'hu', 'tr', 'ro', 'sw', 'ko', 'kk', 'da', 'eo', 'sr',
                       'id', 'lt', 'vo', 'sk', 'he', 'fa', 'bg', 'sl', 'eu', 'lmo',
                       'et', 'hr', 'new', 'te', 'nn', 'th', 'gl', 'el', 'simple',
                       'ms', 'ht', 'bs', 'bpy', 'lb', 'ka', 'is', 'sq', 'la',
                       'br', 'hi', 'az', 'bn', 'mk', 'mr', 'sh', 'tl', 'cy', 'io',
                       'pms', 'lv', 'ta', 'su', 'oc', 'jv', 'nap', 'nds', 'scn', 'be',
                       'ast', 'ku', 'wa', 'af', 'be-x-old', 'an', 'ksh', 'szl', 'fy',
                       'frr', 'zh-yue', 'ur', 'ia', 'ga', 'yi', 'als', 'hy', 'am', 'roa-rup',
                       'map-bms', 'bh', 'co', 'cv', 'dv', 'nds-nl', 'fo', 'fur', 'glk', 'gu',
                       'ilo', 'kn', 'pam', 'csb', 'km', 'lij', 'li', 'ml', 'gv', 'mi', 'mt',
                       'nah', 'ne', 'nrm', 'se', 'nov', 'qu', 'os', 'pi', 'pag', 'ps', 'pdc',
                       'rm', 'bat-smg', 'sa', 'gd', 'sco', 'sc', 'si', 'tg', 'roa-tara', 'tt',
                       'to', 'tk', 'hsb', 'uz', 'vec', 'fiu-vro', 'wuu', 'vls', 'yo', 'diq',
                       'zh-min-nan', 'zh-classical', 'frp', 'lad', 'bar', 'bcl', 'kw', 'mn',
                       'haw', 'ang', 'ln', 'ie', 'wo', 'tpi', 'ty', 'crh', 'jbo', 'ay',
                       'zea', 'eml', 'ky', 'ig', 'or', 'mg', 'cbk-zam', 'kg', 'arc', 'rmy',
                       'gn', 'so', 'kab', 'ks', 'stq', 'ce', 'udm', 'mzn', 'pap',
                       'cu', 'sah', 'tet', 'sd', 'lo', 'ba', 'pnb', 'iu', 'na', 'got', 'bo',
                       'dsb', 'chr', 'cdo', 'hak', 'om', 'my', 'sm', 'ee', 'pcd', 'ug', 'as',
                       'ti', 'av', 'bm', 'zu', 'pnt', 'nv', 'cr', 'pih', 'ss', 've', 'bi', 'rw',
                       'ch', 'arz', 'xh', 'kl', 'ik', 'bug', 'dz', 'ts', 'tn', 'kv', 'tum', 'xal',
                       'st', 'tw', 'bxr', 'ak', 'ab', 'ny', 'fj', 'lbe', 'ki', 'za', 'ff', 'lg',
                       'sn', 'ha', 'sg', 'rn', 'chy', 'mwl', 'pa', 'xmf', 'lez', 'mai']

dbpedia_startswith = set()
for lang in wikipedia_languages:
    dbpedia_startswith.add('http://{}.dbpedia.org/'.format(lang)[:20])


def query_get_adjacent_nodes(vertex_uri):
    """
    :type vertex_uri: str
    """
    return u"""SELECT DISTINCT ?o WHERE {{
                 <{}> ?p ?o
               }}""".format(vertex_uri)


def get_hist_for_uri(endpoint, vertex_uri, depth=4, search_external=False, ext_uri_map=None):
    """
    :type endpoint: SPARQLWrapper
    :type vertex_uri: str
    :type depth: int
    :type search_external: bool
    :type ext_uri_map: dict
    """
    # print 'Starting BFS from URI: ' + vertex_uri
    endpoint.setReturnFormat(JSON)
    if not ext_uri_map:
        ext_uri_map = {
            'http://dbpedia.org': sparql_dbp,
            'http://ru.dbpedia.org': sparql_dbp,
        }
    histogram = []
    discovered = set()
    discovered.add(vertex_uri)
    traverse_now = set()
    traverse_now.add(vertex_uri)
    traverse_next = set()
    histogram.append(len(traverse_now))
    for level in range(0, depth):
        # print ' level {}'.format(level + 1)
        for v in traverse_now:
            # Account only Russian and English DBpedia triples (started with ru and en)
            if v[:20] in dbpedia_startswith:
                continue
            sparql = endpoint
            if search_external:
                for uri_starts, uri_endpoint in ext_uri_map.iteritems():
                    if v.startswith(uri_starts):
                        sparql = uri_endpoint
                        break
            sparql.setQuery(query_get_adjacent_nodes(v))
            try:
                # Some URIs in DBpedia use weird characters that cause an exception, we don't follow such links
                bindings = cjson.decode(sparql.query().response.read())['results']['bindings']
            except SPARQLExceptions.SPARQLWrapperException as e:
                print
                print '  ============================'
                print '  Failed on URI ' + v
                print '    ' + e.msg
                print '    ' + str(e.args)
                print '  ============================'
                print
                continue

            for b in bindings:
                if b['o']['type'] != 'uri':
                    continue
                neighbor = b['o']['value']
                if neighbor not in discovered:
                    traverse_next.add(neighbor)
                    discovered.add(neighbor)
        traverse_now = traverse_next
        traverse_next = set()
        histogram.append(len(traverse_now))  # add number of unique URIs on current level to histogram
    return histogram
