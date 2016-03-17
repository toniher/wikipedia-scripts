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
my $dirout = shift // "out";

# Directory with Wikidata pieces
if ( ! defined( $dir ) ) {
	exit;
}

opendir( DIR, $dir ) or die $!;

my $fork= new Parallel::ForkManager( $procs );

while ( my $file = readdir(DIR) ) {
	
	if ( $file=~/^\./ ) { next; }
	
	my $pid= $fork->start and next;

	my $docsfile = processJSONfile( $dir."/".$file );
	
	my %report;
	$report{"docs"} = $docsfile;

	if ( ! -d $dirout ) {
		mkdir( $dirout );
	}
	
	# Output suitable for bulk upload with CouchDB
	open(FILEOUT, ">", $dirout."/".$file.".json" ) or die "Cannow write";

	print FILEOUT JSON->new->utf8(1)->encode(\%report);
	close( FILEOUT );

	$fork->finish;
}

$fork->wait_all_children;

sub processJSONfile {
	
	my $file = shift;
	my $docs;

	# Process JSON file
	# Line by line is a JSON piece
	
	open ( FILE, "<:encoding(UTF-8)", $file) || die "Cannot open $file";
	

	while ( <FILE> ) {
		
		my $entityStr = $_;
		# Remove final comma
		$entityStr=~s/\,\s*$//g;
		my $entity = JSON->new->utf8(1)->decode($entityStr);
		
		my $doc = processEntity( $entity );

		if ( $doc ) {
			push( @{$docs}, $doc );
		}

	}
	
	close( FILE );
	
	return $docs;
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
			my $object = {};

			my $detail = 0;

			$object->{"_id"} = $id;
			$object->{"langs"} = {};
			$object->{"langs"}->{$lang} = {};
			$object->{"langs"}->{$lang}->{"label"} = $label;
			$object->{"langs"}->{$lang}->{"title"} = $title;
			

			# Handle discrepancy cases
			# Capitalization
			if ( lc( $label ) eq lc( $title ) ) {
				$detail = 1;
			} else {
				my $modifTitle = $title;
				# Remove last parenthesis
				$modifTitle=~s/\s*\(.*?\)\s*$//g;
				
				if ( $label eq $modifTitle ) {
					$detail  = 2;
				} else {
					if ( lc( $label ) eq lc( $modifTitle ) ) {
						$detail = 3;
					}
				}
			}

			$object->{"langs"}->{$lang}->{"detail"} = $detail;

			return $object;
		}
		
	}
	
	return 0;
}

