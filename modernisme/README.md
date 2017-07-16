perl wikidata-mapping.pl colleccions props.json colleccions.csv


perl -lane 'my (@case) = $_=~/(Q\d+)/gimsx; foreach my $ca (@case) { print $ca}' test.c.txt > qlist.txt
sort -u qlist.txt > qlist.collections.txt


cat *qlist.txt | sort -u > all.qlist.txt
