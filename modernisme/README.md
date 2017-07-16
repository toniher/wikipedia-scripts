# Get IDs by sparql
python wikidata-get-IDs.py query.sparql

# Filter IDs 
perl wikidata-filter-id.pl allids listids.txt dirout

# makie the mapping
perl wikidata-mapping.pl colleccions props.json colleccions.csv

# Get extra Q
perl -lane 'my (@case) = $_=~/(Q\d+)/gimsx; foreach my $ca (@case) { print $ca}' test.c.txt > qlist.txt
sort -u qlist.txt > qlist.collections.txt
cat *qlist.txt | sort -u > all.qlist.txt

# Get back Ids
perl wikidata-filter-id.pl ../../wikidata/parts all.qlist.txt qlist


# Counting IDs
less *.json |grep '\"id\":'|wc -l
