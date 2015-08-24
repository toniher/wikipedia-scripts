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

my $configfile = shift // "subsTemplatesFromOther.json";
my $config = Config::JSON->new($configfile);

my $from = $config->get("from") // "";
my $to = $config->get("to") // ""; 
my $exclude = $config->get("exclude") // ("");
my $baselang = $config->get("baselang") // "en";
my $targetlang = $config->get("targetlang") // "ca";
my $sleep = $config->get("sleep") // 5;

# Replacements
my $replacements = $config->get("replace") // {};

# Container for playing with Wikipedias
my $mwcontainer;
# First base
$mwcontainer->{"base"}->{$baselang} = MediaWiki::API->new();
$mwcontainer->{"base"}->{$baselang}->{config}->{api_url} = 'https://'.$baselang.'.wikipedia.org/w/api.php';
# Then target
$mwcontainer->{"target"}->{$targetlang} = MediaWiki::API->new();
$mwcontainer->{"target"}->{$targetlang}->{config}->{api_url} = 'https://'.$targetlang.'.wikipedia.org/w/api.php';

# Username and password.
my $user = $config->get("mw/username") // "";
my $pass = $config->get("mw/password") // "";
my $host = $config->get("mw/host") // "";
my $protocol = $config->get("mw/protocol") // "";
my $path = $config->get("mw/path") // "";

my $iter = 0;

proceed_template( $mwcontainer, $from, $to, $exclude );


sub proceed_template {

	my $mwcontainer = shift;
	my $from = shift;
	my $to = shift;
	my $exclude = shift;

	# What links here

	my $mw = $mwcontainer->{"target"}->{ $targetlang };
	
	# get a list of articles in category
	my $articles = $mw->list ( {
		action => 'query',
		list => 'embeddedin',
		einamespace => 0,
		eititle => $from,
		eilimit => 100
	 } )
	|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};
		
	# Iterate
	foreach (@{$articles}) {
		if ( $_->{ns} == 0 ) {
		
			my $title = $_->{title};
			
			if ( $title ) {		
				if ( inArray( $title, $exclude ) )  {
					next;
				}
				
				# Get interwiki
				my $basetitle = get_interwiki( $title, $mwcontainer, $targetlang );
				# Check if to template		
				
				if ( $basetitle ne '' ) {
					# Get text from original and paste
					my $cut_text = cut_text( $mwcontainer, $baselang, $basetitle, $to );
					#print "***".$cut_text, "\n";
					
					my $rm_text = cut_text( $mwcontainer, $targetlang, $title, $from, "target" );
					#print "###".$cut_text, "\n";

					my $text = $mw->get_page( { title => $title } )->{'*'};
					$rm_text = quotemeta( $rm_text );
					$text =~ s/$rm_text/$cut_text/g;
										
					foreach my $key ( keys %{$replacements} ){
						
						my $match = quotemeta( $key );
						$text =~ s/$match/$replacements->{$key}/g;
					}
					
					print $text;
					# Modify now page
					edit( $mw, $title, $text, "Replace $from" );

				}
				
			}
		}
		
		$iter++;
		
		if ( $iter > 2 ) {
			last;
		}
		
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



sub get_interwiki {
	
	my $entry = shift;
	my $mwcontainer = shift;
	my $lang = shift // "en";
	
	my $basetitle = "";
	
	my $outcome = {};
	
	my $wikidata_url = "http://www.wikidata.org/w/api.php?action=wbgetentities&sites=".$lang."wiki&titles=".$entry."&languages=".$lang."&format=json";
	
	# TODO: Exception handling URL
	my %listiw = &get_iw( from_json(full_get($wikidata_url)) );
	
	if ( $listiw{$baselang."wiki"} ) {
		$basetitle = $listiw{$baselang."wiki"}->{title};
	}	

	return $basetitle;
	
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

sub cut_text {
	
	my $mwcontainer = shift;
	my $baselang = shift;
	my $title = shift;
	my $template = shift;
	my $group = shift // 'base';
	
	print STDERR $title, "\n";
	
	# Process template name
	my $intemplate = $template;
	
	# Language specific - sic
	$intemplate =~ s/Template\://;
	$intemplate =~ s/Plantilla\://;

	
	my $mw = $mwcontainer->{$group}->{ $baselang };

	my $page = $mw->get_page( { title => $title } );
	# print page contents
	my $text = $page->{'*'};
	
	my $detect = "(\{\{".$intemplate.".*?\}\})";
	
	my ( $cut_text ) = $text =~ /$detect/s;
	
	return $cut_text;
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

sub edit {

	my $mw = shift;
	my $pagename = shift;
	my $text = shift;
	my $summary = shift;

	$mw->login( {lgname => $user, lgpassword => $pass } )
	|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};
	
	my $ref = $mw->get_page( { title => $pagename } );
	unless ( $ref->{missing} ) {
			my $timestamp = $ref->{timestamp};
			$mw->edit( {
			  action => 'edit',
			  title => $pagename,
			  basetimestamp => $timestamp, # to avoid edit conflicts
			  text => $text } )
			  || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};
	}

	return 1;
}

