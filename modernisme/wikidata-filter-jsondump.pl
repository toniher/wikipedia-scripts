#!/usr/bin/env perl

use 5.010;

use JSON;
use Parallel::ForkManager;
use Data::Dumper;

use utf8;
binmode(STDOUT, ":utf8");

# Directory of dumps
my $dir = shift;
my $procs = shift // 4;
my $conffile = shift // "conf.json";

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


sub detectEntity {
	
	my $entity = shift;
	my $in = 0;
	
	if ( defined( $entity->{"claims"} ) ) {
		
		$claims = $entity->{"claims"};
		
		foreach my $claim ( keys %{ $claims } ) {
			if ( defined( $claims->{$claim}->{"mainsnak"} ) ) {
				my $mainsnak = $claims->{$claim}->{"mainsnak"};
				if ( defined( $mainsnak->{"snaktype"} ) ) {
					
					if ( $mainsnak->{"snaktype"} eq 'value' ) {
						
						if ( defined( $mainsnak->{"datavalue"} ) ) {
						
							my $datavalue = $mainsnak->{"datavalue"};
							
							my $value = processPvalue( $datavalue );
							
						}
					}
				}
			}
		}
		
	}
	
	return $in;
	
}

sub processEntity {
	
	my $entity = shift;

	my $label = {};
	my $title = {};

	my $id = $entity->{"id"};
	my $type = $entity->{"type"};
	
	my $object = {};

	my $detail = 0;

	$object->{"_id"} = $id;
	$object->{"type"} = $type;
	
	$object->{"langs"} = {};


	
	
	return 0;
}

