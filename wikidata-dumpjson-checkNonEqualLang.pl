#!/usr/bin/env perl

use JSON;
use Parallel::ForkManager;
 
# Directory of dumps
my $dir = shift;
my $procs = shift // 4;

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
	
	open ( FILE, "<", $file) || die "Cannot open $file";
	
	while ( <FILE> ) {
		
		my $entity = JSON->new->utf8(1)->decode($_);
		
		processEntity( $entity );
		
	}
	
	close( FILE );
	
	
}

sub processEntity {
	
	my $entity = shift;
	
	
}

