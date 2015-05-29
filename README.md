# wikipedia-scripts
Repository for handy wikipedia scripts

## List and situation from categories

    category-report-status.pl

* Extract all pages from category(ies)
	* Handle recursively subcategories
* For every page, retrieve data:
	* Size
	* Interwiki in different languages
	* Pagecount (in a defined month)
		* http://stats.grok.se/json/en/201501/Bioinformatics
* Store in hash / JSON
	* Generate MW table (which can be sorted) 

## Replace one template from one Wikipedia to another one Wikipedia

    subsTemplatesFromOther.pl
