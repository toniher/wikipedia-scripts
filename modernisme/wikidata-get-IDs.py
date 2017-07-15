from SPARQLWrapper import SPARQLWrapper, JSON
import pandas as pd
import sys

def main(argv):
		
		
		if len(sys.argv) < 2:
				sys.exit()

		configfile = "query.txt"
		
		if sys.argv[1] :
				configfile = sys.argv[1]
				
		query = open( configfile, 'r').read()

		sparql = SPARQLWrapper("https://query.wikidata.org/sparql")
		
		sparql.setQuery( query )
		
		sparql.setReturnFormat(JSON)
		results = sparql.query().convert()
		
		results_df = pd.io.json.json_normalize(results['results']['bindings'])
		
		for index, row in results_df.iterrows():
				urlvalue = row['item.value']
				value = urlvalue.replace( "http://www.wikidata.org/entity/", "" )
				print value
				

if __name__ == "__main__":
        main(sys.argv[1:])
