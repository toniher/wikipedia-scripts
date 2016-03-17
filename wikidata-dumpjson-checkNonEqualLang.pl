#!/usr/bin/env perl

use JSON;
use Parallel::ForkManager;
use Data::Dumper;
 
use utf8;
binmode(STDOUT, ":utf8");

# Directory of dumps
my $dir = shift;
my $procs = shift // 4;
my $lang = shift // "ca";

# Directory with Wikidata pieces
if ( ! defined( $dir ) ) {
	exit;
}

opendir( DIR, $dir ) or die $!;

my $fork= new Parallel::ForkManager( $procs );

while ( my $file = readdir(DIR) ) {
	
	if ( $file=~/^\./ ) { next; }
	
	my $pid= $fork->start and next;

	processJSONfile( $dir."/".$file );
	
	$fork->finish;
}

$fork->wait_all_children;


sub processJSONfile {
	
	my $file = shift;
	
	# Process JSON file
	# Line by line is a JSON piece
	
	open ( FILE, "<:encoding(UTF-8)", $file) || die "Cannot open $file";
	
	while ( <FILE> ) {
		
		my $entityStr = $_;
		# Remove final comma
		$entityStr=~s/\,\s*$//g;
		my $entity = JSON->new->utf8(1)->decode($entityStr);
		
		processEntity( $entity );
		
	}
	
	close( FILE );
	
	
}

sub processEntity {
	
	my $entity = shift;

	my $label = "";
	my $title = "";

	my $id = $entity->{"id"};
	if ( defined( $entity->{"labels"} ) ) {

		if ( defined( $entity->{"labels"}->{$lang} ) ) {
			$label = $entity->{"labels"}->{$lang}->{"value"};
		}
		
	}

	if ( defined( $entity->{"sitelinks"} ) ) {

		if ( defined( $entity->{"sitelinks"}->{$lang."wiki"} ) ) {
			$title = $entity->{"sitelinks"}->{$lang."wiki"}->{"title"};
		}
		
	}

	if ( $title ) {
		if ( $label ne $title ) {
			print $id.": ".$label."-".$title."\n";
			# TODO: Handle other cases
			# Capitalization
			# Parentheses
			
			# TODO: Submit to DB as a JSON
		}
		
	}
	
}

