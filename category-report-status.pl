#!/usr/bin/env perl -w

use MediaWiki::API;
use LWP::Simple qw(get);
use JSON qw(from_json);
use URI::Escape;
use Data::Dumper;
use Math::Round qw/round/;
use Config::JSON;
use Text::Trim;
use DateTime;
use utf8;

use strict;
use feature ':5.22';

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $store = {};

my $inputfile = shift // "category-report-status.json" ;

my $config = Config::JSON->new( $inputfile );

my $categorystr = $config->get("category") // "Category:Bioinformatics";
my $depth = $config->get("depth") // 1; # Maximum depth of subcategories
my $exclude = $config->get("exclude") // ("Category:Bioinformatics stubs");
my $baselang = $config->get("baselang") // "en";
my $targetlang = $config->get("targetlang") // ( "ca" );
my $sleep = $config->get("sleep") // 5;
my $user = $config->get("user") // 0;
my $passwd = $config->get("password") // 0;
my $method = $config->get("method") // "wikitext";

my $temp = {};

# Container for playing with Wikipedias
my $mwcontainer;
# First base
$mwcontainer->{"base"}->{$baselang} = MediaWiki::API->new();

if ( $user && $passwd ) {
	$mwcontainer->{"base"}->{$baselang}->login( { lgname => $user, lgpassword => $passwd } );
}

$mwcontainer->{"base"}->{$baselang}->{config}->{api_url} = 'https://'.$baselang.'.wikipedia.org/w/api.php';
# Then targets
foreach my $tlang ( @{$targetlang} ) {
	$mwcontainer->{"target"}->{$tlang} = MediaWiki::API->new();

	if ( $user && $passwd ) {
		$mwcontainer->{"target"}->{$tlang}->login( { lgname => $user, lgpassword => $passwd } );
	}

	$mwcontainer->{"target"}->{$tlang}->{config}->{api_url} = 'https://'.$tlang.'.wikipedia.org/w/api.php';
}

my ( @header ) = ( "Article", "Caràcters", "Visites", "Interwikis", "Categoria" );
my ( @headerlang ) = ( "Article", "Caràcters" );

my ( @categories ) = split( /,/, $categorystr );

foreach my $category ( @categories ) {

	proceed_category( $category, $mwcontainer, 0 );

}

if ( $method eq 'wikitext' ) {

	print "{| class='wikitable sortable'\n";

	my $headstr = "! ". join( " !! ", @header );

	foreach my $tlang ( sort( @{$targetlang} ) ) {
		my ( @arr ) = ();
		foreach my $p ( @headerlang ) {
			push( @arr, "$p ($tlang)" );
		}
		$headstr .= " !! ".join( " !! ", @arr );
	}

	$headstr .= "\n";

	print $headstr;


	foreach my $title ( keys %{$store} ) {

		my @row;

		push( @row, "[[".$baselang.":".$title."|".$title."]]" );
		push( @row, $store->{$title}->{"length"} );
		push( @row, $store->{$title}->{"count"} );
		push( @row, $store->{$title}->{"listcount"} );
		push( @row, "[[".$baselang.":".$store->{$title}->{"category"}."|".$store->{$title}->{"category"}."]]" );

		foreach my $tlang ( sort( @{$targetlang} ) ) {

			if ( $store->{$title}->{"target"}->{$tlang} ) {

				push( @row, "[[".$tlang.":".$store->{$title}->{"target"}->{$tlang}->{"title"}."|".$store->{$title}->{"target"}->{$tlang}->{"title"}."]]" );
				push( @row, $store->{$title}->{"target"}->{$tlang}->{"length"} );

			} else {
				push( @row, ( "" , "" ) )
			}


		}

		print "|-\n|\n";
		print join( " || ", @row )."\n";

	}



	#End of table
	print "|}\n";

}

# TODO: Avoid printing at this stage. Keep in hash. Store by baselang title as key
#print "|-", "\n";
#print "| ", "[[:$baselang:$title|".$title."]]", "||", $store->{$title}->{"length"}, "||", $store->{$title}->{"count"}, "||", $store->{$title}->{"listcount"}, "||", $store->{$title}->{"target"}, "||", "[[:$baselang:$cat|".$cat."]]\n";

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

	my $iter = 0;
	foreach (@{$articles}) {
		if ( $_->{ns} == 0 ) {

			$iter++;
			if ( $iter > 4 ) {
				#last; Uncomment for testing purposes
			}

			my $title = $_->{title};

			unless ( $store->{$title} ) {

				if ( inArray( $title, $exclude ) )  {
					next;
				}

				print STDERR "** ", $title, "\n";

				$store->{$title} = {};
				$store->{$title}->{"target"} = {};

				my $length =  get_length( $title, $mw );

				$store->{$title}->{"length"} = $length;

				my $pagecount = get_pagecount( $title, $baselang );

				$store->{$title}->{"count"} = $pagecount;

				$store->{$title}->{"category"} = $cat;

				my $out = get_interwiki( $title, $mwcontainer, $baselang ) ;
				if ( $out->{"listcount"} ) {
					$store->{$title}->{"listcount"} = $out->{"listcount"};
				} else {
					$store->{$title}->{"listcount"} = 0;
				}

				if ( $out->{"present"} ) {
					$store->{$title}->{"present"} = $out->{"present"};
				}

				if ( $out->{"target"} ) {
					foreach my $key ( keys %{ $out->{"target"} } ) {
						$store->{$title}->{"target"}->{$key} = {};
						if ( $out->{"target"}->{$key}->{"title"} ) {
							$store->{$title}->{"target"}->{$key}->{"title"} = $out->{"target"}->{$key}->{"title"};
						}
						if ( $out->{"target"}->{$key}->{"length"} ) {
							$store->{$title}->{"target"}->{$key}->{"length"} = $out->{"target"}->{$key}->{"length"};
						}
					}
				}

			}
		}

		sleep(int($sleep));
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
	|| return -1;

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

  my $dts = (DateTime->now)->subtract( months => 6 );
  my $dte = (DateTime->now)->subtract( months => 5 );



	my $dates = substr( $dts->ymd(""), 0, -2 )."0100";
	my $datee = substr( $dte->ymd(""), 0, -2 )."0100";

	my $url = "https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/$lang.wikipedia/all-access/user/".uri_escape_utf8( $entry )."/monthly/$dates/$datee";
	print STDERR $url, "\n";
	my $full_get = trim( full_get( $url ) );

	if ( $full_get eq "-1" || $full_get eq "" ) {
		return -1;
	} else {

		my $jsonobj = from_json( $full_get );

		if ( $jsonobj ) {

			my $count_total = 0;
			if ( $jsonobj->{"items"} ) {
				my $stat = $jsonobj->{"items"}->[0];
				$count_total = $stat->{"views"};
			}
			return $count_total;
		} else {
			return -1;
		}

	}

}

sub get_interwiki {

	my $entry = shift;
	my $mwcontainer = shift;
	my $lang = shift // "en";

	my $outcome = {};

	my $wikidata_url = "http://www.wikidata.org/w/api.php?action=wbgetentities&sites=".$lang."wiki&titles=".uri_escape_utf8( $entry )."&languages=".$lang."&format=json";

	# TODO: Exception handling URL
	my $full_get = full_get($wikidata_url );
	my @listiw = ();
	my %listiw;

	if ( $full_get ne "-1" ) {

		%listiw = &get_iw( from_json( $full_get ) );
		( @listiw ) = keys %listiw;
	}

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

	if ( $retry > 0 ) {
		sleep( $sleep );
	}

	if ( $retry > 10 ) {
		return "-1";
	}

	my $content = get($url);
	$retry++;
	full_get($url, $retry) unless defined $content;

	return $content;

}
