#!/usr/bin/env perl

use 5.010;

use JSON;
use Parallel::ForkManager;
use Data::Dumper;

use utf8;
binmode(STDOUT, ":utf8");

# Directory of dumps
my $dir = shift;
my $conffile = shift // "ids.txt";
my $dirout = shift // "filter";
my $procs = shift // 4;

my %ids = processIds( $conffile );

# Directory with Wikidata pieces
if ( ! defined( $dir ) ) {
	exit;
}

if ( ! -d $dirout ) {
	mkdir( $dirout );
}

opendir( DIR, $dir ) or die $!;

my $fork= new Parallel::ForkManager( $procs );

while ( my $file = readdir(DIR) ) {
	
	if ( $file=~/^\./ ) { next; }
	
	my $pid= $fork->start and next;

	open($fhout, ">", $dirout."/".$file.".json" ) or die "Cannow write";

	&processJSONfile( $dir."/".$file, $fhout );
	
	close( $fhout );

	$fork->finish;
}

$fork->wait_all_children;

sub processJSONfile {
	
	my $file = shift;
	my $fhout = shift;

	# Process JSON file
	# Line by line is a JSON piece
	
	open ( FILE, "<:encoding(UTF-8)", $file) || die "Cannot open $file";
	

	while ( <FILE> ) {
		
		my $pre = $_;

		my $doc;
		

		$doc = detectString( $pre );
		
		if ( $doc ) {
			print $fhout $pre;
		}

	}                             
	
	close( FILE );
	
	return 1;
}



sub detectString {
	
	my $entity = shift;
	my $in = 0;
	my ($id) = $_=~/\"id\"\:\"(\S+?)\"/;
	
	if ( defined( $ids{$id} ) ) {
		$in = 1;
	}
	
	return $in;
	
}



sub processIds {
	
	my $file = shift;
	
	%ids = {};
	
	open ( FILE, "<:encoding(UTF-8)", $file) || die "Cannot open $file";
	

	while ( <FILE> ) {
		my ($id) = $_=~/^(Q\S+)/g;
		$ids{$id} = 1;
	}
	
	close( FILE );
	
	return %ids;
	
}

