* Get IDs by sparql

python wikidata-get-IDs.py query.sparql

* Filter IDs 

perl wikidata-filter-id.pl allids listids.txt dirout

* Perform the mapping (export CSV)

perl wikidata-mapping.pl colleccions props.json colleccions.csv

* Perform the mapping with corresp of Q (export CSV)

perl wikidata-mapping.pl colleccions props.json colleccions.csv corresp.qlist.txt

* Retrive all Qs

perl -lane 'my (@case) = $_=~/(Q\d+)/gimsx; foreach my $ca (@case) { print $ca}' test.c.txt > qlist.txt

sort -u qlist.txt > qlist.collections.txt

cat *qlist.txt | sort -u > all.qlist.txt

* Get back Ids

perl wikidata-filter-id.pl ../../wikidata/parts all.qlist.txt qlist

* Corresp of Ids

perl wikidata-get-label.pl qlist all.qlist.txt corresp.qlist.txt


* Counting IDs

less *.json |grep '\"id\":'|wc -l

* Getting columns and filtering Q
 cut -f9 all.20170719.csv |sort -u > instancia-de.txt

perl -lane 'my (@case) = $_=~/\«(\S.*?)\»/gimsx; foreach my $ca (@case) { print $ca}' instancia-de.txt | sort -u >  instancia-de.tot.txt
perl -lane 'my (@case) = $_=~/(Q\d+?)\b/gimsx; foreach my $ca (@case) { print $ca}' instancia-de.txt | sort -u >  instancia-q.tot.txt

* Remove excluded IDs

comm -3 all-pre.txt exclude-ids.txt > all.txt



