#!/usr/bin/env perl

use 5.010;

use JSON;
use Parallel::ForkManager;
use Data::Dumper;

use utf8;
binmode(STDOUT, ":utf8");

# Directory of dumps
my $dir = shift;
my $filein = shift // "in.csv";
my $fileout = shift // "out.csv";
my $procs = shift // 4;

my %qhash = processInFile( $filein );

print STDERR Dumper( \%qhash );

# Directory with Wikidata pieces
if ( ! defined( $dir ) ) {
	exit;
}


opendir( DIR, $dir ) or die $!;

open($fhout, ">:utf8", $fileout ) or die "Cannow write";

my $fork= new Parallel::ForkManager( $procs );


while ( my $file = readdir(DIR) ) {
	
	if ( $file=~/^\./ ) { next; }
	
	my $pid= $fork->start and next;


	my $content = &processJSONfile( $dir."/".$file );
	
	if ( $content ne '' ) {
		print $fhout $content;
	}
	
	$fork->finish;
}


$fork->wait_all_children;

close( $fhout );

sub processJSONfile {
	
	my $file = shift;
	my $text = "";

	# Process JSON file
	# Line by line is a JSON piece
	
	open ( FILE, "<:encoding(UTF-8)", $file) || die "Cannot open $file";
	

	while ( <FILE> ) {
		
		my $entityStr = $_;
	
		# Remove final comma
		$entityStr=~s/\,\s*$//g;
		my $entity = JSON->new->utf8(1)->decode($entityStr);
				

		my $content = processEntity( $entity );
		
		if ( $content ne '' ) {
			
			$text.= $content; 
		
		}
	}                             
	
	close( FILE );
	
	return $text;
}


sub processEntity {
	
	my $entity = shift;
    
	my $text = "";
		
	my $id = $entity->{"id"};
	
	if ( defined( $qhash{ $id } ) ) {
	
		my $label = "";
		
		if ( defined( $entity->{"labels"} ) ) {
			
			if ( defined( $entity->{"labels"}->{"ca"} ) ) {
				if ( defined( $entity->{"labels"}->{"ca"}->{"value"} ) ) {
					$label = $entity->{"labels"}->{"ca"}->{"value"};
				}
			}
	
		}

        print STDERR $id."\t".$label."\n" ;		
		$text = $id."\t".$label."\n" ;
	
	}
	
	return $text;
	
}

sub processInFile {
	
	my $file = shift;
	my %qhash;
		
	open ( FILE, "<", $file) || die "Cannot open $file";
	

	while ( <FILE> ) {
		my ( $id ) = $_=~/^(Q\d+)/;
		$qhash{$id} = 1;
	}
	
	close( FILE );

	
	return %qhash;
	
}
