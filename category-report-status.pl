#!/usr/bin/env perl -w
 
use MediaWiki::API;
use LWP::Simple qw(get);
use JSON qw(from_json);
use URI::Escape;
use Data::Dumper;
use utf8; 

use 5.010;
binmode STDOUT, ":utf8";

#TODO: Load stuff via JSON

# Category
my $category = "Category:Bioinformatics";
my $depth = 1; # Maximum depth of subcategories
my @exclude = ();
my $baselang = "en";
my @targetlang = ( "ca" );

# Language

my $articles = {};

# Container for playing with Wikipedias
my $mwcontainer;
# First base
$mwcontainer->{"base"}->{$baselang} = MediaWiki::API->new();
$mwcontainer->{"base"}->{$baselang}->{config}->{api_url} = 'https://'.$baselang.'.wikipedia.org/w/api.php';
# Then targets
foreach my $tlang ( @targetlang ) {
	$mwcontainer->{"target"}->{$tlang} = MediaWiki::API->new();
	$mwcontainer->{"target"}->{$tlang}->{config}->{api_url} = 'https://'.$tlang.'.wikipedia.org/w/api.php';
}

proceed_category( $category, $mwcontainer, 0 );


sub proceed_category {

	my $cat = shift;
	my $mwcontainer = shift;
	my $step = shift;

	my $mw = $mwcontainer->{"base"}->{ $baselang };
	
	print $step, "\n";
	
	if ( $step > $depth ) {
		return;
	}
	
	# get a list of articles in category
	my $articles = $mw->list ( {
		action => 'query',
		list => 'categorymembers',
		cmtitle => $cat,
		cmlimit => 'max' } )
	|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

	my $categories = $mw->list ( {
		action => 'query',
		list => 'categorymembers',
		cmtitle => $cat,
		cmtype => 'subcat',
		cmlimit => 'max' } )
	|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

	# and print the article titles
	foreach (@{$articles}) {
		print "$_->{title}\n";
		print "LENGTH: ", get_length( $_->{title}, $mw ), "\n";
		print "COUNT: ", get_pagecount( $_->{title} ), "\n";
		my $out = get_interwiki( $_->{title}, $mwcontainer ) ;
		if ( $out->{"list"} ) {
			print "LIST: ", $out->{"list"} , "\n";
		}
		if ( $out->{"target"} ) {
			foreach my $key ( keys %{ $out->{"target"} } ) {
				print $key, "\t", "TITLE: ",  $out->{"target"}->{$key}->{"title"}, "\t", $out->{"target"}->{$key}->{"length"}, "\n";
			}
		}
		# Detect Category, proceed.
		sleep(1);
	}
	
	foreach (@{$categories}) {
		print "CAT: ".$_->{title}."\n";
		proceed_category( $_->{title}, $mw, $step + 1 );
		sleep(1);
	}
}

# Length of page
sub get_length {
 
	my $entry = shift;
	my $mw = shift;
	
	my $articles = $mw->api ( {
		action => 'query',
		titles => $entry,
		prop => 'info',
		redirects => '' } )
	|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

	if ( $articles ) {
		if ( $articles->{"query"}->{"pages"}->{"-1"} ) {
			return 0;
		} else {
			foreach my $page ( keys %{$articles->{"query"}->{"pages"} } ){
				return $articles->{"query"}->{"pages"}->{$page}->{"length"};
			}	
			
		}
	} else {
		return 0;
	}
} 

# Length of page
sub get_pagecount {
 
	my $entry = shift;
	my $lang = shift // "en";
	my $date = "201501"; # TODO: Generate from current date
	
	# TODO: Exception handling URL
	my $url = "http://stats.grok.se/json/$lang/$date/".uri_escape_utf8($entry);

	my $jsonobj = from_json(get($url)); 
	
	if ( $jsonobj ) {
	
		my $count_total = avg_values ( $jsonobj->{"daily_views"} );
		return $count_total;
	} else {
		return -1;
	}
	

}

sub get_interwiki {
	
	my $entry = shift;
	my $mwcontainer = shift;
	my $lang = shift // "en";
	
	my $outcome = {};
	
	my $wikidata_url = "http://www.wikidata.org/w/api.php?action=wbgetentities&sites=".$lang."wiki&titles=".uri_escape_utf8($entry)."&languages=".$lang."&format=json";
	
	# TODO: Exception handling URL
	my %listiw = &get_iw( from_json(get($wikidata_url)) );
	my ( @listiw ) = keys %listiw;
	
	if ( $#listiw > 0 ) { # We assume baselang there

		$outcome->{"target"} = ();

		my @targets = keys %{$mwcontainer->{"target"}};
		
		foreach my $targetlang ( @targets ) {

			my $key = $targetlang."wiki";

			if ( $listiw{ $key } ) {
				
				my $thash = {};
				$thash->{"title"} = $listiw{ $key }->{"title"};
				$thash->{"length"} = get_length( $thash->{"title"}, $mwcontainer->{"target"}->{$targetlang} );
				
				$outcome->{"target"}->{$targetlang} = $thash;
			}
			
		}
	
		
		# Remove wiki from lang names
		for (@listiw) {
			s/wiki//;
		}
	
		$outcome->{"list"} = join(",", sort @listiw);
	}
	

	return $outcome;
	
}


sub avg_values {
	
	my $hash = shift;
	my $num = 0;
	my $sum = 0;
	
	foreach my $key ( keys %{$hash} ) {
		my $val = $hash->{$key};
		$sum = $sum + ( $val );
		$num++;
	}
	
	if ( $num > 0 ) {
		return $sum / $num ;
	} else {
		return -1;
	}
	
}

# Return interwiki list
sub get_iw {
 
	my ( @iw ) = ();
	my $object = shift;
	foreach my $page ( keys %{$object->{"entities"}} ){
		return %{$object->{"entities"}->{$page}->{"sitelinks"}};
	}
	return @iw;
} 
