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

my $category = $config->get("category") // "Category:Bioinformatics";
my $depth = $config->get("depth") // 1; # Maximum depth of subcategories
my $exclude = $config->get("exclude") // ("Category:Bioinformatics stubs");
my $baselang = $config->get("baselang") // "en";
my $targetlang = $config->get("targetlang") // ( "ca" );
my $sleep = $config->get("sleep") // 5;

my $temp = {};

# Container for playing with Wikipedias
my $mwcontainer;
# First base
$mwcontainer->{"base"}->{$baselang} = MediaWiki::API->new();
$mwcontainer->{"base"}->{$baselang}->{config}->{api_url} = 'https://'.$baselang.'.wikipedia.org/w/api.php';
# Then targets
foreach my $tlang ( @{$targetlang} ) {
	$mwcontainer->{"target"}->{$tlang} = MediaWiki::API->new();
	$mwcontainer->{"target"}->{$tlang}->{config}->{api_url} = 'https://'.$tlang.'.wikipedia.org/w/api.php';
}

# Header of table
print "{| class='wikitable sortable'\n";
print "! Title || Length || Count || Interwiki || Present || Target";

proceed_category( $category, $mwcontainer, 0 );


sub proceed_category {

	my $cat = shift;
	my $mwcontainer = shift;
	my $step = shift;

	my $mw = $mwcontainer->{"base"}->{ $baselang };
	
	print STDERR $step, "\n";
	
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
		if ( $_->{ns} == 0 ) {
		
			my $title = $_->{title};
			
			unless ( $temp->{$title} ) {
		
				if ( inArray( $title, $exclude ) )  {
					next;
				}

				print STDERR "** ", $title, "\n";

				my $list = {};
				$list->{$title} = {};
				$temp->{$title} = 1;
				
				$list->{$title}->{"length"} = get_length( $title, $mw );

				$list->{$title}->{"count"} = get_pagecount( $title );

				my $out = get_interwiki( $title, $mwcontainer ) ;
				if ( $out->{"listcount"} ) {
					$list->{$title}->{"listcount"} = $out->{"listcount"};
				}
				if ( $out->{"present"} ) {
					$list->{$title}->{"present"} = $out->{"present"};
				}
				if ( $out->{"target"} ) {
					foreach my $key ( keys %{ $out->{"target"} } ) {
						$list->{$title}->{"target"}.= "\t". $key. "\t". "TITLE: ". $out->{"target"}->{$key}->{"title"}. "\t". "LENGTH: ". $out->{"target"}->{$key}->{"length"};
					}
				}

				print "|-", "\n";
				print "| ", $title, "||", $list->{$title}->{"length"}, "||", $list->{$title}->{"count"}, "||", $list->{$title}->{"listcount"}, "||", $list->{$title}->{"present"}, "||", $list->{$title}->{"target"}, "\n";
			}
		}
		sleep(int(sleep));
	}
	
	foreach (@{$categories}) {

		if ( inArray( $_->{title}, $exclude ) )  {
			next;
		}

		print STDERR "CAT: ".$_->{title}."\n";
		proceed_category( $_->{title}, $mwcontainer, $step + 1 );
		sleep(int($sleep));
	}
}

#End of table
print "|}\n";

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
	
	my $url = "http://stats.grok.se/json/$lang/$date/".$entry;

	my $jsonobj = from_json(full_get($url)); 
	
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

