#!/usr/bin/env perl -w
 
use MediaWiki::API;
use LWP::Simple qw(get);
use JSON qw(from_json);
use URI::Escape;
use Data::Dumper;
use Math::Round qw/round/;
use Config::JSON;
use utf8; 


use 5.010;
binmode STDOUT, ":utf8";

my $config = Config::JSON->new("category-report-status.json");

my $from = $config->get("from") // "";
my $to = $config->get("to") // ""; 
my $exclude = $config->get("exclude") // ("");
my $baselang = $config->get("baselang") // "en";
my $targetlang = $config->get("targetlang") // "ca";
my $sleep = $config->get("sleep") // 5;

my $temp = {};

# Container for playing with Wikipedias
my $mwcontainer;
# First base
$mwcontainer->{"base"}->{$baselang} = MediaWiki::API->new();
$mwcontainer->{"base"}->{$baselang}->{config}->{api_url} = 'https://'.$baselang.'.wikipedia.org/w/api.php';
# Then target
$mwcontainer->{"target"}->{$targetlang} = MediaWiki::API->new();
$mwcontainer->{"target"}->{$targetlang}->{config}->{api_url} = 'https://'.$tlang.'.wikipedia.org/w/api.php';


proceed_template( $mwcontainer, $from, $to, $exclude );


sub proceed_template {


	# What links here
	# Iterate
	
		# Get interwiki
		# Check if to template
		
		# Open. Get template
		
		# Cut, paste, save
		# Log

}


sub inArray {

	my $elem = shift;
	my $array = shift;

	my %params = map { $_ => 1 } @{$array};
	if( exists( $params{$elem} ) ) {
		return 1;
	} else {
		return 0;
	}

}



sub get_interwiki {
	
	my $entry = shift;
	my $mwcontainer = shift;
	my $lang = shift // "en";
	
	my $outcome = {};
	
	my $wikidata_url = "http://www.wikidata.org/w/api.php?action=wbgetentities&sites=".$lang."wiki&titles=".$entry."&languages=".$lang."&format=json";
	
	# TODO: Exception handling URL
	my %listiw = &get_iw( from_json(full_get($wikidata_url)) );
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
		
		$outcome->{"listcount"} = $#listiw + 1;
		$outcome->{"list"} = join(",", sort @listiw);

		$outcome->{"present"} = 0;
		
		foreach my $target ( @targets ) {
			if ( inArray( $target, \@listiw ) ) {
				$outcome->{"present"} = 1;
			}
		}

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
		return round( $sum / $num );
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


sub full_get {

	my $url = shift;
	my $retry = shift // 0;
	
	if ( $retry > 5 ) {
		die "too many retries";
	}
	
	$content = get($url);
	$retry++;
	full_get($url, $retry) unless defined $content;
	
	return $content;
	
}

