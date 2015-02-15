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

# Language

my $mw = MediaWiki::API->new();
# URL
$mw->{config}->{api_url} = 'https://en.wikipedia.org/w/api.php';

proceed_category( $category, $mw, 0 );


sub proceed_category {

	my $cat = shift;
	my $mw = shift;
	my $step = shift;

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
		#get_length( $_->{title}, $mw );
		print "\n";
		# Detect Category, proceed.
	}
	
	foreach (@{$categories}) {
		print "CAT: ".$_->{title}."\n";
		proceed_category( $_->{title}, $mw, $step + 1 );
		sleep(1);
	}
}

# Length of page
sub get_length {
 
 	# TODO: Change to MediaWiki::API
	my $site = shift;
	my $entry = shift;
	
	if ( defined( $sites{$site} ) ) {
		my $url = $sites{$site}."/w/api.php?action=query&titles=".uri_escape_utf8($entry)."&prop=info&format=json&redirects";
		
		my $object = from_json(get($url));
		if ( $object ) {
			if ( $object->{"query"}->{"pages"}->{"-1"} ) {
				return $site.":".0;
			}
			foreach my $page ( keys %{$object->{"query"}->{"pages"}} ){
				return $site.":".$object->{"query"}->{"pages"}->{$page}->{"length"};
			}
		} else {
			return $site.":".-1;
		}
	} else {
		return $site.":".-1;
	}
} 
