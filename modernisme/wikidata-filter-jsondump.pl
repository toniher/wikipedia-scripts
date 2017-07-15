#!/usr/bin/env perl

use 5.010;

use JSON;
use Parallel::ForkManager;
use Data::Dumper;

use utf8;
binmode(STDOUT, ":utf8");

# Directory of dumps
my $dir = shift;
my $conffile = shift // "conf.json";
my $dirout = shift // "filter";
my $procs = shift // 4;

my $conf = processConfFile( $conffile );

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
		
		my $entityStr = $_;
		my $pre = $_;
	
		# Remove final comma
		$entityStr=~s/\,\s*$//g;
		my $entity = JSON->new->utf8(1)->decode($entityStr);
		
		my $doc = detectEntity( $entity );

		if ( $doc ) {
			print $fhout $pre;
		}

	}                             
	
	close( FILE );
	
	return 1;
}


sub detectEntity {
	
	my $entity = shift;
	my $in = 0;
	
	if ( defined( $conf->{"props"} ) ) {
		
		foreach my $prop ( $conf->{"props"} ) {
	
			if ( defined( $entity->{"claims"} ) ) {
				
				$claims = $entity->{"claims"};
				
				# Exists pro
				if ( defined( $claims->{$prop} ) ) {
					
					my $propVal = $conf->{"props"}->{$prop};
				
					if ( defined( $claims->{$prop}->{"mainsnak"} ) ) {
						my $mainsnak = $claims->{$prop}->{"mainsnak"};
						if ( defined( $mainsnak->{"snaktype"} ) ) {
							
							if ( $mainsnak->{"snaktype"} eq 'value' ) {
								
								if ( defined( $mainsnak->{"datavalue"} ) ) {
								
									my $datavalue = $mainsnak->{"datavalue"};
									
									my $value = processQvalue( $datavalue );
									
									if ( $value ) {
										if ( $value eq $propVal ) {
											$in = 1;
										}
									}
									
								}
							}
						}
					}
					
				}
				
			}
			
		}
	}
	
	return $in;
	
}

sub processConfFile {
	
	my $file = shift;
	
	my $jsonStr = "";
	
	open ( FILE, "<:encoding(UTF-8)", $file) || die "Cannot open $file";
	

	while ( <FILE> ) {
		$jsonStr.= $_;
	}
	
	close( FILE );

	
	my $confEntity = JSON->new->utf8(1)->decode($jsonStr);

	return $confEntity;
	
}

sub processQvalue {
	
	my $datavalue = shift;
	my $value = 0;
	
	if ( defined( $datavalue->{"value"} ) ) {
		
		if ( defined( $datavalue->{"value"}->{"entity-type"} ) ) {
		
			if ( $datavalue->{"value"}->{"entity-type"} eq 'item' ) {
				$value =  $datavalue->{"value"}->{"id"};
			}
		
		}
	}
	
	return $value;
	
}


