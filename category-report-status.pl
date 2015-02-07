#!/usr/bin/env perl -w
 
use MediaWiki::API;
use LWP::Simple qw(get);
use JSON qw(from_json);
use URI::Escape;
use Data::Dumper;
use utf8; 

use 5.010;
binmode STDOUT, ":utf8";

# GetOpt

# Category
# Language

my $mw = MediaWiki::API->new();
# URL
$mw->{config}->{api_url} = 'http://en.wikipedia.org/w/api.php';

# get a list of articles in category
my $articles = $mw->list ( {
action => 'query',
list => 'categorymembers',
cmtitle => 'Category:Perl',
cmlimit => 'max' } )
|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

# and print the article titles
foreach (@{$articles}) {
	print "$_->{title}\n";
}



# Length of page
sub get_length {
 
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
